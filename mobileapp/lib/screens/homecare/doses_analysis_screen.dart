import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import 'hc_common.dart';

final _analysisProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 29));
  final results = await Future.wait([
    hcFetchAll(ref, '/homecare/doses/', params: {
      'page_size': 1000,
      'from': from.toUtc().toIso8601String(),
    }),
    dio.get('/homecare/dashboard/summary/'),
  ]);
  return {
    'doses': results[0] as List,
    'summary': (results[1] as dynamic).data as Map<String, dynamic>,
  };
});

/// Doses analysis: 30-day status mix, adherence trend and per-patient league.
class HomecareDosesAnalysisScreen extends ConsumerWidget {
  const HomecareDosesAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(_analysisProvider);

    return HcAsyncBody(
      value: analysis,
      onRefresh: () async => ref.refresh(_analysisProvider.future),
      builder: (d) {
        final doses = (d['doses'] as List).cast<Map>();
        final trend =
            (((d['summary'] as Map)['adherence_trend'] as List?) ?? [])
                .cast<Map>();

        final counts = <String, int>{};
        for (final x in doses) {
          final s = (x['status'] ?? '').toString();
          counts[s] = (counts[s] ?? 0) + 1;
        }
        final taken = counts['taken'] ?? 0;
        final missed = counts['missed'] ?? 0;
        final finalized = taken + missed;
        final adherence =
            finalized > 0 ? (taken / finalized * 100).round() : 0;

        // Per-patient adherence league (lowest first — needs attention)
        final byPatient = <String, List<int>>{}; // name -> [taken, finalized]
        for (final x in doses) {
          final name = (x['patient_name'] ?? '—').toString();
          final s = (x['status'] ?? '').toString();
          if (s != 'taken' && s != 'missed') continue;
          final e = byPatient.putIfAbsent(name, () => [0, 0]);
          e[1] += 1;
          if (s == 'taken') e[0] += 1;
        }
        final league = byPatient.entries
            .map((e) => (
                  e.key,
                  e.value[1] > 0
                      ? (e.value[0] / e.value[1] * 100).round()
                      : 0
                ))
            .toList()
          ..sort((a, b) => a.$2.compareTo(b.$2));

        const statusMeta = [
          ('taken', 'Taken', hcGreen),
          ('pending', 'Pending', hcAmber),
          ('missed', 'Missed', hcRed),
          ('skipped', 'Skipped', hcSlate),
          ('not_given', 'Not given', Color(0xFF9F1239)),
        ];
        final total = doses.length;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'ANALYTICS',
              title: 'Dose analysis',
              subtitle: 'Last 30 days of medication administration',
              icon: Icons.query_stats_rounded,
              gradient: const [
                Color(0xFF1E3A8A),
                Color(0xFF0284C7),
                Color(0xFF0EA5E9)
              ],
              chips: [
                HcHeroChip(
                    icon: Icons.medication_rounded, label: '$total doses'),
                HcHeroChip(
                    icon: Icons.percent_rounded,
                    label: '$adherence% adherence'),
              ],
            ),
            if (total > 0)
              HcPanel(
                title: 'Status mix',
                subtitle: 'Distribution of the last 30 days',
                icon: Icons.pie_chart_rounded,
                color: hcBlue,
                child: Row(children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 34,
                        sections: [
                          for (final m in statusMeta)
                            if ((counts[m.$1] ?? 0) > 0)
                              PieChartSectionData(
                                value: (counts[m.$1] ?? 0).toDouble(),
                                color: m.$3,
                                radius: 38,
                                showTitle: false,
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final m in statusMeta)
                          if ((counts[m.$1] ?? 0) > 0)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3),
                              child: Row(children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color: m.$3,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(m.$2,
                                        style: const TextStyle(
                                            fontSize: 12))),
                                Text(
                                    '${counts[m.$1]} (${(counts[m.$1]! / total * 100).round()}%)',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ]),
                            ),
                      ],
                    ),
                  ),
                ]),
              ),
            if (trend.isNotEmpty)
              HcPanel(
                title: '7-day adherence trend',
                icon: Icons.show_chart_rounded,
                color: hcTeal,
                child: SizedBox(
                  height: 160,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 25),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            interval: 25,
                            getTitlesWidget: (v, _) => Text('${v.round()}%',
                                style: const TextStyle(fontSize: 9)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (v, _) {
                              final i = v.round();
                              if (i < 0 || i >= trend.length) {
                                return const SizedBox.shrink();
                              }
                              final date = DateTime.tryParse(
                                  trend[i]['date'].toString());
                              return Text(
                                  date != null ? '${date.day}' : '',
                                  style: const TextStyle(fontSize: 9));
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          color: hcTeal,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                              show: true,
                              color: hcTeal.withValues(alpha: 0.12)),
                          spots: [
                            for (var i = 0; i < trend.length; i++)
                              FlSpot(
                                  i.toDouble(),
                                  ((trend[i]['rate'] as num?) ?? 0)
                                      .toDouble()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            HcPanel(
              title: 'Patient adherence league',
              subtitle: 'Lowest adherence first — needs attention',
              icon: Icons.leaderboard_rounded,
              color: hcPurple,
              child: league.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                          child: Text('No finalized doses in range.')),
                    )
                  : Column(
                      children: league.take(12).map((e) {
                        final color = e.$2 >= 80
                            ? hcGreen
                            : e.$2 >= 50
                                ? hcAmber
                                : hcRed;
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            SizedBox(
                                width: 120,
                                child: Text(e.$1,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                    value: e.$2 / 100,
                                    minHeight: 8,
                                    color: color),
                              ),
                            ),
                            SizedBox(
                                width: 44,
                                child: Text('${e.$2}%',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: color))),
                          ]),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}
