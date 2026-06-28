import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

/// Bottom sheet to choose catalog facets (set / color / type / rarity / alt-art).
class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterProvider);
    final notifier = ref.read(filterProvider.notifier);
    final options = ref.watch(facetOptionsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: options.when(
          loading: () => const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(height: 120, child: Center(child: Text('$e'))),
          data: (opts) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    TextButton(
                      onPressed: filter.hasActiveFacets ? notifier.clearFacets : null,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                _FacetGroup(
                  label: 'Set',
                  options: opts.sets,
                  selected: filter.setCode,
                  onSelected: notifier.setSet,
                ),
                _FacetGroup(
                  label: 'Color',
                  options: opts.colors,
                  selected: filter.color,
                  onSelected: notifier.setColor,
                ),
                _FacetGroup(
                  label: 'Type',
                  options: opts.types,
                  selected: filter.type,
                  onSelected: notifier.setType,
                ),
                _FacetGroup(
                  label: 'Rarity',
                  options: opts.rarities,
                  selected: filter.rarity,
                  onSelected: notifier.setRarity,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alt-art only'),
                  value: filter.altArtOnly,
                  onChanged: notifier.setAltArtOnly,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FacetGroup extends StatelessWidget {
  const _FacetGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              for (final o in options)
                FilterChip(
                  label: Text(o),
                  selected: selected == o,
                  onSelected: (sel) => onSelected(sel ? o : null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
