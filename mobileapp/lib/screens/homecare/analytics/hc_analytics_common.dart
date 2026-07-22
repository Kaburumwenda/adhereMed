import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../hc_common.dart';

// ═════════════════════════════════════════════════════════════════
//  Shared analytics widgets — donut, bar chart, line chart, range
//  selector, legend, progress bar, empty state, sub-nav, stat tile.
//  All built on fl_chart + the HcHero / HcPanel / HcKpi primitives
//  from hc_common.dart.  Premium, modern, professional.
// ═════════════════════════════════════════════════════════════════

const _rangeOptions = [
  ('Today', 'today'),
  ('Yesterday', 'yesterday'),
  ('Last 7 days', '7d'),
  ('Last 30 days', '30d'),
  ('Last 90 days', '90d'),
  ('Last year', '1y'),
  ('All time', 'all'),
  ('Custom', 'custom'),
];

String rangeLabel(String range) => switch (range) {
      'today' => "Today's",
      'yesterday' => "Yesterday's",
      '7d' => '7-day',
      '30d' => '30-day',
      '90d' => '90-day',
      '1y' => '1-year',
      'all' => 'All-time',
      'custom' => 'Custom',
      _ => '30-day',
    };

/// Compact range dropdown used inside panel action slots.
class HcRangeSelector extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final void Function(DateTimeRange? range)? onCustomRange;
  final DateTimeRange? customRange;
  const HcRangeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.onCustomRange,
    this.customRange,
  });

  @override
  State<HcRangeSelector> createState() => _HcRangeSelectorState();
}

class _HcRangeSelectorState extends State<HcRangeSelector> {
  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = widget.customRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: initial,
    );
    if (picked != null) {
      widget.onCustomRange?.call(picked);
      widget.onChanged('custom');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCustom = widget.value == 'custom';
    final displayText = isCustom && widget.customRange != null
        ? '${DateFormat('d MMM').format(widget.customRange!.start)} - ${DateFormat('d MMM').format(widget.customRange!.end)}'
        : _rangeOptions.firstWhere((r) => r.$2 == widget.value,
            orElse: () => _rangeOptions.first).$1;

    return PopupMenuButton<String>(
      tooltip: 'Select date range',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cs.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant, width: 0.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.date_range_rounded, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(displayText,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface)),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 16, color: cs.onSurfaceVariant),
        ]),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 40,
          child: Text('Select date range',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, letterSpacing: 0.4)),
        ),
        const PopupMenuDivider(height: 1),
        for (final r in _rangeOptions)
          PopupMenuItem<String>(
            value: r.$2,
            height: 44,
            child: Row(children: [
              Icon(
                r.$2 == widget.value ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: r.$2 == widget.value ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(
                r.$2 == 'custom' && widget.customRange != null
                    ? '${r.$1}: ${DateFormat('d MMM').format(widget.customRange!.start)} - ${DateFormat('d MMM').format(widget.customRange!.end)}'
                    : r.$1,
                style: TextStyle(fontSize: 13, fontWeight: r.$2 == widget.value ? FontWeight.w700 : FontWeight.w500, color: cs.onSurface),
              )),
            ]),
          ),
      ],
      onSelected: (v) {
        if (v == 'custom') {
          _pickCustomRange();
        } else {
          widget.onChanged(v);
        }
      },
    );
  }
}

/// Donut ring chart built on fl_chart PieChart.
class HcDonutRing extends StatelessWidget {
  final List<({String label, num value, Color color})> segments;
  final double size;
  final String centerValue;
  final String centerLabel;
  const HcDonutRing({
    super.key,
    required this.segments,
    this.size = 160,
    this.centerValue = '',
    this.centerLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: size * 0.30,
            sections: [
              for (final s in segments)
                if (s.value > 0)
                  PieChartSectionData(
                    value: s.value.toDouble(),
                    color: s.color,
                    radius: size * 0.09,
                    showTitle: false,
                  ),
            ],
          ),
        ),
        if (centerValue.isNotEmpty)
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(centerValue,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800)),
            if (centerLabel.isNotEmpty)
              Text(centerLabel,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
      ]),
    );
  }
}

/// Legend list item — coloured dot, label, value.
class HcLegendRow extends StatelessWidget {
  final String label;
  final num value;
  final Color color;
  const HcLegendRow(
      {super.key, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(
            width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant))),
        Text('$value', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Progress bar with label, value, and percentage.
class HcProgressBarRow extends StatelessWidget {
  final String label;
  final num value;
  final int pct;
  final Color color;
  final IconData? icon;
  final String? trailing;
  const HcProgressBarRow({
    super.key,
    required this.label,
    required this.value,
    required this.pct,
    required this.color,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant))),
        const SizedBox(width: 8),
        Text(trailing ?? '$value', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
                value: (pct / 100).clamp(0, 1), minHeight: 6, color: color),
          ),
        ),
      ]),
    );
  }
}

/// Bar chart with paired (grouped) or single bars.
class HcBarChart extends StatelessWidget {
  final List<List<num>> groups; // each inner list = bars at one x position
  final List<String> labels;
  final List<Color> colors; // per-bar colors within a group
  final double height;
  final bool showValues;
  final String Function(num)? yFormatter;
  final bool scrollable;
  final double? scrollWidth;
  const HcBarChart({
    super.key,
    required this.groups,
    required this.labels,
    required this.colors,
    this.height = 200,
    this.showValues = false,
    this.yFormatter,
    this.scrollable = false,
    this.scrollWidth,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxVal = groups.expand((g) => g).fold<num>(0, (a, b) => a > b ? a : b);
    final barWidth = groups.length > 15 ? 4.0 : groups.length > 8 ? 6.0 : 10.0;
    final effectiveMaxY = (maxVal * 1.15).toDouble().clamp(1, double.infinity);

    final chart = BarChart(
      BarChartData(
        maxY: effectiveMaxY.toDouble(),
        gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxVal > 0 ? (maxVal / 4).ceilToDouble() : 1,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: cs.outlineVariant, strokeWidth: 0.5)),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < groups.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                for (var j = 0; j < groups[i].length; j++)
                  BarChartRodData(
                    toY: groups[i][j].toDouble(),
                    color: colors[j % colors.length],
                    width: barWidth,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3), topRight: Radius.circular(3)),
                  ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Transform.rotate(
                  angle: labels.length > 6 ? -0.5 : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(labels[i],
                        style: const TextStyle(fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    if (!scrollable) {
      return SizedBox(height: height, child: chart);
    }

    final interval = effectiveMaxY / 4;
    final yValues = [for (var i = 4; i >= 0; i--) (interval * i)];

    return SizedBox(
      height: height,
      child: Row(children: [
        SizedBox(
          width: 38,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 34),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final v in yValues)
                  Text(
                    yFormatter != null ? yFormatter!(v) : v.round().toString(),
                    style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = scrollWidth ??
                  (labels.length * 50.0 > c.maxWidth
                      ? labels.length * 50.0
                      : c.maxWidth);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: w, child: chart),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Line chart supporting 1+ series with gradient fill.
class HcLineChart extends StatelessWidget {
  final List<({String label, Color color, List<num> values})> series;
  final List<String> labels;
  final double height;
  final double? minY;
  final double? maxY;
  final String Function(num)? yFormatter;
  final bool scrollable;
  final double? scrollWidth;
  const HcLineChart({
    super.key,
    required this.series,
    required this.labels,
    this.height = 220,
    this.minY,
    this.maxY,
    this.yFormatter,
    this.scrollable = false,
    this.scrollWidth,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allVals = series.expand((s) => s.values);
    final minV = allVals.isEmpty ? 0.0 : allVals.reduce((a, b) => a < b ? a : b).toDouble();
    final maxV = allVals.isEmpty ? 1.0 : allVals.reduce((a, b) => a > b ? a : b).toDouble();
    final computedMinY = minY ?? (minV * 0.9).floorToDouble();
    final computedMaxY = maxY ?? (maxV * 1.1).ceilToDouble();
    final effectiveMaxY = computedMaxY == computedMinY ? computedMinY + 1 : computedMaxY;

    final chart = LineChart(
      LineChartData(
        minY: computedMinY,
        maxY: effectiveMaxY,
        gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (effectiveMaxY - computedMinY) / 4,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: cs.outlineVariant, strokeWidth: 0.5)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: scrollable
              ? const AxisTitles(sideTitles: SideTitles(showTitles: false))
              : AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    getTitlesWidget: (v, _) => Text(
                        yFormatter != null ? yFormatter!(v) : v.round().toString(),
                        style: const TextStyle(fontSize: 9)),
                  ),
                ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: labels.length > 10 ? (labels.length / 4).ceilToDouble() : 1,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[i], style: const TextStyle(fontSize: 9)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          for (final s in series)
            LineChartBarData(
              isCurved: true,
              color: s.color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [s.color.withValues(alpha: 0.18), s.color.withValues(alpha: 0.0)])),
              spots: [
                for (var i = 0; i < s.values.length; i++)
                  FlSpot(i.toDouble(), s.values[i].toDouble()),
              ],
            ),
        ],
      ),
    );

    if (!scrollable) {
      return SizedBox(height: height, child: chart);
    }

    final interval = (effectiveMaxY - computedMinY) / 4;
    final yValues = [for (var i = 4; i >= 0; i--) computedMinY + interval * i];

    return SizedBox(
      height: height,
      child: Row(children: [
        SizedBox(
          width: 38,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final v in yValues)
                  Text(
                    yFormatter != null ? yFormatter!(v) : v.round().toString(),
                    style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = scrollWidth ??
                  (labels.length * 50.0 > c.maxWidth
                      ? labels.length * 50.0
                      : c.maxWidth);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: w, child: chart),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Empty state placeholder.
class HcEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  const HcEmptyState({super.key, required this.icon, required this.title, this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 36, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 8),
        Text(title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
          ),
      ]),
    );
  }
}

/// Stat tile used inside panels (e.g. visit summary, insurance amounts).
class HcStatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const HcStatTile({super.key, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

/// Sub-navigation chip row linking to all 9 analytics pages.
class HcAnalyticsSubNav extends StatefulWidget {
  final String currentPath;
  const HcAnalyticsSubNav({super.key, required this.currentPath});

  static const _items = [
    ('Overview', '/homecare/analytics', Icons.dashboard_rounded, hcTeal),
    ('Patients', '/homecare/analytics/patients', Icons.people_alt_rounded, hcBlue),
    ('Equipment', '/homecare/analytics/equipment', Icons.devices_rounded, Color(0xFF06B6D4)),
    ('Financials', '/homecare/analytics/financials', Icons.payments_rounded, hcAmber),
    ('Workforce', '/homecare/analytics/caregivers', Icons.volunteer_activism_rounded, hcIndigo),
    ('Visits', '/homecare/analytics/visits', Icons.event_note_rounded, hcPurple),
    ('Adherence', '/homecare/analytics/adherence', Icons.medication_rounded, hcGreen),
    ('Escalations', '/homecare/analytics/escalations', Icons.warning_amber_rounded, hcRed),
    ('Insurance', '/homecare/analytics/insurance', Icons.shield_rounded, Color(0xFFF97316)),
  ];

  @override
  State<HcAnalyticsSubNav> createState() => _HcAnalyticsSubNavState();
}

class _HcAnalyticsSubNavState extends State<HcAnalyticsSubNav> {
  final _scrollController = ScrollController();
  static const _chipWidth = 120.0;
  static const _chipSpacing = 8.0;
  static const _listPadding = 16.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
  }

  @override
  void didUpdateWidget(HcAnalyticsSubNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  void _scrollToActive() {
    if (!_scrollController.hasClients) return;
    final activeIndex = HcAnalyticsSubNav._items
        .indexWhere((item) => item.$2 == widget.currentPath);
    if (activeIndex < 0) return;
    final itemOffset =
        activeIndex * (_chipWidth + _chipSpacing) + _listPadding;
    final viewportWidth = _scrollController.position.viewportDimension;
    final currentOffset = _scrollController.offset;
    final targetEnd = itemOffset + _chipWidth;
    if (itemOffset < currentOffset) {
      _scrollController.animateTo(
        itemOffset - _listPadding,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else if (targetEnd > currentOffset + viewportWidth) {
      _scrollController.animateTo(
        targetEnd - viewportWidth + _listPadding,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _listPadding),
        itemCount: HcAnalyticsSubNav._items.length,
        separatorBuilder: (_, __) => const SizedBox(width: _chipSpacing),
        itemBuilder: (context, i) {
          final item = HcAnalyticsSubNav._items[i];
          final active = widget.currentPath == item.$2;
          return SizedBox(
            width: _chipWidth,
            child: FilterChip(
              selected: active,
              label: Text(item.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              avatar: Icon(item.$3, size: 15),
              selectedColor: item.$4.withValues(alpha: 0.18),
              checkmarkColor: item.$4,
              labelStyle: TextStyle(color: active ? item.$4 : null),
              onSelected: (_) => context.go(item.$2),
            ),
          );
        },
      ),
    );
  }
}

/// Analytics page scaffold: hero + sub-nav + scrollable content + loading/error.
class HcAnalyticsPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData heroIcon;
  final List<Color>? heroGradient;
  final List<Widget> heroChips;
  final Widget? heroAction;
  final List<Widget> body;
  final bool loading;
  final Future<void> Function()? onRefresh;
  final String currentPath;

  const HcAnalyticsPage({
    super.key,
    required this.title,
    required this.subtitle,
    this.heroIcon = Icons.analytics_rounded,
    this.heroGradient,
    this.heroChips = const [],
    this.heroAction,
    required this.body,
    this.loading = false,
    this.onRefresh,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'ANALYTICS',
              title: title,
              subtitle: subtitle,
              icon: heroIcon,
              gradient: heroGradient,
              chips: heroChips,
              trailing: heroAction ??
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(18)),
                    child: Icon(heroIcon, color: Colors.white, size: 30),
                  ),
            ),
            const SizedBox(height: 4),
            HcAnalyticsSubNav(currentPath: currentPath),
            const SizedBox(height: 8),
            ...body,
          ],
        ),
      ),
      if (loading)
        Positioned(
            top: 0, left: 0, right: 0,
            child: LinearProgressIndicator(color: hcTeal, minHeight: 3)),
    ]);
  }
}

/// KPI grid — 2 columns on mobile, wrapping automatically.
class HcKpiGrid extends StatelessWidget {
  final List<({String label, String value, IconData icon, Color color, String? hint})> items;
  const HcKpiGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.45,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => HcKpi(
          label: items[i].label,
          value: items[i].value,
          icon: items[i].icon,
          color: items[i].color,
          hint: items[i].hint,
        ),
      ),
    );
  }
}

/// Ranked list item with avatar rank number, title, subtitle, trailing.
class HcRankTile extends StatelessWidget {
  final int rank;
  final String title;
  final String? subtitle;
  final Color rankColor;
  final Widget? trailing;
  const HcRankTile({
    super.key,
    required this.rank,
    required this.title,
    this.subtitle,
    this.rankColor = hcTeal,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: rankColor.withValues(alpha: 0.14), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$rank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: rankColor)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (subtitle != null)
              Text(subtitle!, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        )),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Paginated table with simple prev/next controls.
class HcPaginatedTable extends StatefulWidget {
  final List<String> headers;
  final List<List<Widget>> rows;
  final int pageSize;
  const HcPaginatedTable({super.key, required this.headers, required this.rows, this.pageSize = 15});

  @override
  State<HcPaginatedTable> createState() => _HcPaginatedTableState();
}

class _HcPaginatedTableState extends State<HcPaginatedTable> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pageCount = (widget.rows.length / widget.pageSize).ceil().clamp(1, 99999);
    final start = (_page - 1) * widget.pageSize;
    final pageRows = widget.rows.skip(start).take(widget.pageSize).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12,
          dataRowMinHeight: 42,
          dataRowMaxHeight: 52,
          headingRowHeight: 40,
          columns: widget.headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)))).toList(),
          rows: [
            for (var i = 0; i < pageRows.length; i++)
              DataRow(cells: pageRows[i].map((cell) => DataCell(cell)).toList()),
          ],
        ),
      ),
      if (widget.rows.length > widget.pageSize)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: _page > 1 ? () => setState(() => _page--) : null,
              iconSize: 20,
            ),
            Text('$pageCount pages · ${widget.rows.length} rows',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: _page < pageCount ? () => setState(() => _page++) : null,
              iconSize: 20,
            ),
          ]),
        ),
    ]);
  }
}

/// Simple search field for analytics tables.
class HcSearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  const HcSearchField({super.key, required this.hintText, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12.5),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 12.5),
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(width: 0.5, color: Theme.of(context).colorScheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(width: 0.5, color: Theme.of(context).colorScheme.outlineVariant)),
      ),
    );
  }
}
