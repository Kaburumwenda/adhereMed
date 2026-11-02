"""CSV and Excel writers for the inventory report platform.

Both consume the same ``{'columns', 'rows', 'totals'}`` payload the PDF does, so
a spreadsheet export always matches the printed sheet. The workbook gets a
branded title row, a scope/filter block, a styled header and frozen panes.
"""
from __future__ import annotations

import csv
import io
from datetime import date, datetime

from django.utils import timezone

from .render import format_value


#: Characters Excel forbids in a worksheet name.
_SHEET_BAD = set('[]:*?/\\')


def _sheet_title(text, fallback='Report'):
    """Worksheet name safe for openpyxl.

    The tab name is the user-editable report title, so it can legitimately
    contain ``/`` ("ABC / XYZ classification") — openpyxl raises ``ValueError``
    on those and the whole export 500s.
    """
    cleaned = ''.join('-' if ch in _SHEET_BAD else ch
                      for ch in str(text or '')).strip().strip("'")
    return cleaned[:31].strip() or fallback


def _plain(value, type_):
    """Value suitable for a spreadsheet cell (numbers stay numeric)."""
    if value is None or value == '':
        return ''
    if type_ in ('int', 'num'):
        try:
            number = float(value)
            return int(number) if type_ == 'int' else number
        except (TypeError, ValueError):
            return str(value)
    if type_ in ('money', 'percent'):
        try:
            return float(value)
        except (TypeError, ValueError):
            return str(value)
    if type_ in ('date', 'datetime'):
        # openpyxl refuses tz-aware datetimes outright ("Excel does not support
        # timezones") and the whole workbook save raises. Datasets hand back
        # ``USE_TZ`` aware values, so localise and drop the tzinfo here.
        if isinstance(value, datetime):
            try:
                if timezone.is_aware(value):
                    value = timezone.localtime(value)
            except Exception:
                pass
            return value.replace(tzinfo=None)
        if isinstance(value, date):
            return value
        return str(value)
    return str(value)


def build_csv(*, columns, rows, totals=None, include_totals=True) -> bytes:
    """RFC-4180 CSV with a UTF-8 BOM so Excel opens it correctly."""
    buf = io.StringIO()
    writer = csv.writer(buf, quoting=csv.QUOTE_MINIMAL)
    writer.writerow([c['label'] for c in columns])
    for row in rows:
        writer.writerow([
            format_value(row.get(c['key']), c['type']).replace('—', '')
            for c in columns
        ])
    if include_totals and totals:
        writer.writerow([
            ('TOTAL' if index == 0
             else format_value(totals.get(c['key']), c['type']).replace('—', ''))
            for index, c in enumerate(columns)
        ])
    # BOM: without it Excel reads "KSh 1,234.56" columns as mojibake.
    return ('\ufeff' + buf.getvalue()).encode('utf-8')


def build_xlsx(*, columns, rows, totals=None, title='', subtitle='',
               scope_lines=None, palette=None, include_totals=True,
               business_name='', breakdown=None, charts=None) -> bytes:
    """Styled workbook: title band, scope block, frozen header, totals row."""
    from openpyxl import Workbook
    from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
    from openpyxl.utils import get_column_letter

    palette = palette or {}
    primary = (palette.get('primary') or '#2f6dff')
    secondary = (palette.get('secondary') or '#143ce1')
    accent = (palette.get('accent') or '#37d6ff')

    def hexcode(value, fallback):
        text = str(value or '').lstrip('#')
        if len(text) == 3:
            text = ''.join(ch * 2 for ch in text)
        if len(text) != 6:
            return fallback.lstrip('#')
        try:
            int(text, 16)
            return text.upper()
        except ValueError:
            return fallback.lstrip('#')

    PRIMARY = hexcode(primary, '#2f6dff')
    SECONDARY = hexcode(secondary, '#143ce1')
    ACCENT = hexcode(accent, '#37d6ff')

    wb = Workbook()
    ws = wb.active
    ws.title = _sheet_title(title, 'Report')

    last_col = max(1, len(columns))
    thin = Side(style='thin', color='E2E8F0')

    # ── Title band ──────────────────────────────────────────────────────
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=last_col)
    cell = ws.cell(row=1, column=1, value=(business_name or 'AdhereMed'))
    cell.font = Font(bold=True, size=15, color=SECONDARY)
    cell.alignment = Alignment(vertical='center')

    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=last_col)
    cell = ws.cell(row=2, column=1, value=title or 'Inventory report')
    cell.font = Font(bold=True, size=12, color='0F172A')

    row_cursor = 3
    if subtitle:
        ws.merge_cells(start_row=row_cursor, start_column=1,
                       end_row=row_cursor, end_column=last_col)
        cell = ws.cell(row=row_cursor, column=1, value=subtitle)
        cell.font = Font(size=9, italic=True, color='64748B')
        row_cursor += 1

    for line in (scope_lines or [])[:4]:
        ws.merge_cells(start_row=row_cursor, start_column=1,
                       end_row=row_cursor, end_column=last_col)
        cell = ws.cell(row=row_cursor, column=1, value=line)
        cell.font = Font(size=9, color='64748B')
        row_cursor += 1

    ws.merge_cells(start_row=row_cursor, start_column=1,
                   end_row=row_cursor, end_column=last_col)
    stamp = timezone.localtime(timezone.now()).strftime('%d %b %Y, %H:%M')
    cell = ws.cell(row=row_cursor, column=1,
                   value=f'Generated {stamp} · {len(rows):,} rows')
    cell.font = Font(size=8, color='94A3B8')
    row_cursor += 2

    # ── Header ──────────────────────────────────────────────────────────
    header_row = row_cursor
    for index, col in enumerate(columns, start=1):
        cell = ws.cell(row=header_row, column=index, value=str(col['label']).upper())
        cell.font = Font(bold=True, size=9, color='FFFFFF')
        cell.fill = PatternFill('solid', fgColor=SECONDARY)
        cell.alignment = Alignment(
            horizontal=('right' if col['type'] in ('int', 'num', 'money', 'percent')
                        else 'center' if col['type'] in ('date', 'datetime', 'badge')
                        else 'left'),
            vertical='center', wrap_text=True)
        cell.border = Border(bottom=Side(style='medium', color=ACCENT))
    ws.row_dimensions[header_row].height = 26

    # ── Body ────────────────────────────────────────────────────────────
    number_formats = {
        'int': '#,##0',
        'num': '#,##0.##',
        'money': '#,##0.00',
        'percent': '0.0"%"',
        'date': 'DD MMM YYYY',
        'datetime': 'DD MMM YYYY HH:MM',
    }
    for r_index, row in enumerate(rows, start=header_row + 1):
        stripe = PatternFill('solid', fgColor='F4F7FF') if (r_index - header_row) % 2 == 0 else None
        for c_index, col in enumerate(columns, start=1):
            cell = ws.cell(row=r_index, column=c_index,
                           value=_plain(row.get(col['key']), col['type']))
            cell.border = Border(bottom=thin)
            if stripe:
                cell.fill = stripe
            fmt = number_formats.get(col['type'])
            if fmt:
                cell.number_format = fmt
            if col['type'] in ('int', 'num', 'money', 'percent'):
                cell.alignment = Alignment(horizontal='right')
            elif col['type'] in ('date', 'datetime'):
                cell.alignment = Alignment(horizontal='center')

    # ── Totals ──────────────────────────────────────────────────────────
    if include_totals and totals:
        t_row = header_row + len(rows) + 1
        for index, col in enumerate(columns, start=1):
            value = 'TOTAL' if index == 1 else _plain(totals.get(col['key']), col['type'])
            cell = ws.cell(row=t_row, column=index, value=value)
            cell.font = Font(bold=True, size=9)
            cell.fill = PatternFill('solid', fgColor='E8EEFF')
            cell.border = Border(top=Side(style='medium', color=PRIMARY))
            fmt = number_formats.get(col['type'])
            if fmt:
                cell.number_format = fmt

    # ── Layout ──────────────────────────────────────────────────────────
    for index, col in enumerate(columns, start=1):
        label = str(col['label'])
        widest = max([len(label)] + [len(str(row.get(col['key']) or ''))
                                     for row in rows[:300]])
        ws.column_dimensions[get_column_letter(index)].width = min(
            max(10, widest + 3), 46)

    ws.freeze_panes = ws.cell(row=header_row + 1, column=1)
    ws.auto_filter.ref = (f'A{header_row}:'
                          f'{get_column_letter(last_col)}{header_row + len(rows)}')

    if charts:
        _add_charts_sheet(wb, charts, title=title, palette=palette)

    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _add_charts_sheet(wb, charts, *, title='', palette=None):
    """Second worksheet holding real Excel charts (not pictures of charts).

    Keeping the source numbers on the same sheet means the charts stay
    editable and re-scale when the tenant tweaks a figure — a rendered PNG in
    a spreadsheet is dead weight for an analyst.
    """
    from openpyxl.chart import BarChart, LineChart, PieChart, Reference
    from openpyxl.styles import Alignment, Font, PatternFill

    palette = palette or {}
    primary = str(palette.get('primary') or '#2f6dff').lstrip('#')
    accent = str(palette.get('accent') or '#37d6ff').lstrip('#')

    charts = [c for c in charts if c.get('points')]
    if not charts:
        return None

    ws = wb.create_sheet('Visuals')
    ws.sheet_view.showGridLines = False
    ws.column_dimensions['A'].width = 34
    ws.column_dimensions['B'].width = 16

    ws['A1'] = 'Data visuals'
    ws['A1'].font = Font(bold=True, size=14, color=primary)
    ws['A2'] = title or 'Inventory report'
    ws['A2'].font = Font(size=10, color='64748B')

    row = 4
    for chart in charts[:4]:
        heading = ws.cell(row=row, column=1, value=str(chart.get('title') or ''))
        heading.font = Font(bold=True, size=11)
        subtitle = ws.cell(row=row, column=2,
                           value=str(chart.get('subtitle') or ''))
        subtitle.font = Font(size=8, color='94A3B8')
        row += 1

        header_row = row
        for col, text in enumerate(('Label', 'Value'), start=1):
            cell = ws.cell(row=header_row, column=col, value=text)
            cell.font = Font(bold=True, size=9, color='FFFFFF')
            cell.fill = PatternFill('solid', fgColor=primary.upper())
            cell.alignment = Alignment(horizontal='center')

        points = chart['points']
        for offset, point in enumerate(points, start=1):
            ws.cell(row=header_row + offset, column=1,
                    value=str(point.get('label') or ''))
            value_cell = ws.cell(row=header_row + offset, column=2,
                                 value=float(point.get('value') or 0))
            value_cell.number_format = '#,##0.00'
        last_row = header_row + len(points)
        row = last_row + 2

        data = Reference(ws, min_col=2, min_row=header_row, max_row=last_row)
        cats = Reference(ws, min_col=1, min_row=header_row + 1, max_row=last_row)
        kind = chart.get('kind')
        if kind == 'donut':
            obj = PieChart()
            obj.holeSize = 55
        elif kind == 'line':
            obj = LineChart()
        else:
            obj = BarChart()
            obj.type = 'col'
            obj.gapWidth = 40
        obj.title = str(chart.get('title') or '')
        obj.height = 7.2
        obj.width = 15.5
        obj.add_data(data, titles_from_data=True)
        obj.set_categories(cats)
        try:
            series = obj.series[0]
            series.graphicalProperties.solidFill = primary.upper()
            series.graphicalProperties.line.solidFill = primary.upper()
            series.graphicalProperties.line.width = 22000
        except Exception:
            pass
        anchor = f'D{header_row}'
        ws.add_chart(obj, anchor)
    return ws

