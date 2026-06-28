import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../util/format.dart';

class _Point {
  _Point(this.at, this.market);
  final DateTime at;
  final double market;
}

/// Price history chart for a variant (fetched from the API; needs a connection).
class PriceHistorySheet extends ConsumerStatefulWidget {
  const PriceHistorySheet({super.key, required this.variantId, required this.title});
  final String variantId;
  final String title;

  static Future<void> show(BuildContext context, {required String variantId, required String title}) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => PriceHistorySheet(variantId: variantId, title: title),
    );
  }

  @override
  ConsumerState<PriceHistorySheet> createState() => _PriceHistorySheetState();
}

class _PriceHistorySheetState extends ConsumerState<PriceHistorySheet> {
  String _range = '3m';

  Future<List<_Point>> _load() async {
    final raw = await ref.read(apiClientProvider).priceHistory(widget.variantId, _range);
    return raw
        .cast<Map<String, dynamic>>()
        .where((p) => p['marketPrice'] != null)
        .map((p) => _Point(DateTime.parse(p['capturedAt'] as String), (p['marketPrice'] as num).toDouble()))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price history', style: theme.textTheme.titleLarge),
            Text(widget.title, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final r in const ['1m', '3m', '6m', '1y', 'all'])
                  ChoiceChip(
                    label: Text(r),
                    selected: _range == r,
                    onSelected: (_) => setState(() => _range = r),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: FutureBuilder<List<_Point>>(
                future: _load(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return const Center(child: Text('Price history needs a connection.'));
                  }
                  final pts = snap.data ?? const [];
                  if (pts.isEmpty) return const Center(child: Text('No price data for this range.'));
                  if (pts.length == 1) {
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(formatUsd(pts.first.market), style: theme.textTheme.headlineMedium),
                        Text('on ${formatDate(pts.first.at)}'),
                        const SizedBox(height: 8),
                        const Text('History fills in as prices are captured.', style: TextStyle(fontSize: 12)),
                      ]),
                    );
                  }
                  return _Chart(points: pts);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.points});
  final List<_Point> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = points.map((p) => p.market).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.1 + 0.01;

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(formatUsd(s.y), TextStyle(color: theme.colorScheme.onInverseSurface)))
                .toList(),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (v, _) {
              return Text(formatUsd(v), style: theme.textTheme.labelSmall);
            }),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i != 0 && i != points.length - 1) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(formatDate(points[i].at), style: theme.textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].market)],
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }
}
