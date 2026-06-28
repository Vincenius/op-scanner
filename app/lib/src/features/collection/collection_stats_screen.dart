import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/collection_repository.dart';
import '../../providers.dart';
import '../../util/format.dart';

class CollectionStatsScreen extends ConsumerWidget {
  const CollectionStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(allCollectionEntriesProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Collection stats'),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) => entries.isEmpty
            ? const Center(child: Text('Add cards to see your stats.'))
            : _StatsBody(entries: entries),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.entries});
  final List<CollectionEntry> entries;

  double _value(CollectionEntry e) => (e.variant.marketPrice ?? 0) * e.item.quantity;

  @override
  Widget build(BuildContext context) {
    final totalValue = entries.fold<double>(0, (s, e) => s + _value(e));
    final copies = entries.fold<int>(0, (s, e) => s + e.item.quantity);
    final uniqueCards = entries.map((e) => e.card.cardCode).toSet().length;

    // Value by set.
    final bySet = <String, double>{};
    for (final e in entries) {
      bySet[e.card.setCode] = (bySet[e.card.setCode] ?? 0) + _value(e);
    }
    final sets = bySet.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topSets = sets.take(6).toList();

    // Top entries by line value.
    final top = [...entries]..sort((a, b) => _value(b).compareTo(_value(a)));
    final topEntries = top.take(5).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _StatCard(label: 'Total value', value: formatUsd(totalValue)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _StatCard(label: 'Cards', value: '$copies'),
            const SizedBox(width: 8),
            _StatCard(label: 'Entries', value: '${entries.length}'),
            const SizedBox(width: 8),
            _StatCard(label: 'Unique', value: '$uniqueCards'),
          ],
        ),
        const SizedBox(height: 24),
        Text('Value by set', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(height: 200, child: _ValueBySetChart(data: topSets)),
        const SizedBox(height: 24),
        Text('Most valuable', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final e in topEntries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('${e.card.name} · ${e.item.variantId}', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${e.item.quantity}× · ${e.item.condition}'),
            trailing: Text(formatUsd(_value(e)), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueBySetChart extends StatelessWidget {
  const _ValueBySetChart({required this.data});
  final List<MapEntry<String, double>> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = data.isEmpty ? 1.0 : data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.15,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              formatUsd(rod.toY),
              TextStyle(color: theme.colorScheme.onInverseSurface, fontSize: 11),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(data[i].key, style: theme.textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: data[i].value,
                color: theme.colorScheme.primary,
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]),
        ],
      ),
    );
  }
}
