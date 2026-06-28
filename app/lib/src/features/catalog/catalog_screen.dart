import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform.dart';
import '../../data/catalog_repository.dart';
import '../../data/sync_service.dart';
import '../../providers.dart';
import '../../util/format.dart';
import 'catalog_filter.dart';
import 'filter_sheet.dart';
import 'widgets/card_thumb.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterProvider);
    final sync = ref.watch(syncControllerProvider);
    final localCount = ref.watch(localVariantCountProvider).asData?.value ?? 0;

    return Scaffold(
      floatingActionButton: isScanningSupported
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/scan'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan'),
            )
          : null,
      appBar: AppBar(
        title: const Text('Catalog'),
        actions: [
          PopupMenuButton<CatalogSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: filter.sort,
            onSelected: ref.read(filterProvider.notifier).setSort,
            itemBuilder: (_) => [
              for (final s in CatalogSort.values)
                PopupMenuItem(value: s, child: Text(s.label)),
            ],
          ),
          IconButton(
            tooltip: 'Sync catalog',
            onPressed: sync.running ? null : ref.read(syncControllerProvider.notifier).sync,
            icon: const Icon(Icons.sync),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: _SearchAndFilterBar(filter: filter),
        ),
      ),
      body: Column(
        children: [
          if (sync.running) _SyncBanner(progress: sync.progress),
          if (sync.error != null)
            MaterialBanner(
              content: Text('Sync failed: ${sync.error}'),
              actions: [
                TextButton(
                  onPressed: ref.read(syncControllerProvider.notifier).sync,
                  child: const Text('Retry'),
                ),
              ],
            ),
          Expanded(
            child: localCount == 0 && !sync.running
                ? _EmptyState(onSync: ref.read(syncControllerProvider.notifier).sync)
                : const _CatalogGrid(),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilterBar extends ConsumerWidget {
  const _SearchAndFilterBar({required this.filter});
  final CatalogFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search name or code…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                filled: true,
              ),
              textInputAction: TextInputAction.search,
              onChanged: ref.read(filterProvider.notifier).setQuery,
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: filter.activeFacetCount > 0,
            label: Text('${filter.activeFacetCount}'),
            child: IconButton.filledTonal(
              onPressed: () => FilterSheet.show(context),
              icon: const Icon(Icons.tune),
              tooltip: 'Filters',
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({this.progress});
  final SyncProgress? progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final label = switch (p?.phase) {
      'images' => 'Caching images ${p!.done}/${p.total}',
      'complete' => 'Done',
      _ => 'Syncing catalog…',
    };
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            if (p?.fraction != null) Text('${((p!.fraction!) * 100).round()}%'),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSync});
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_download_outlined, size: 56),
            const SizedBox(height: 12),
            Text(
              'No catalog yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Download the card catalog to browse offline.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSync,
              icon: const Icon(Icons.sync),
              label: const Text('Sync catalog'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogGrid extends ConsumerWidget {
  const _CatalogGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(catalogItemsProvider);
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No cards match your filters.'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            childAspectRatio: 0.62,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _CatalogCardTile(item: items[i]),
        );
      },
    );
  }
}

class _CatalogCardTile extends StatelessWidget {
  const _CatalogCardTile({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = item.variant;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go('/card/${v.cardId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CardThumb(thumbPath: v.thumbUrl),
                  if (v.isAltArt)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _Chip(label: v.variantLabel ?? 'Alt', color: theme.colorScheme.tertiary),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${v.variantId}${v.rarity != null ? ' · ${v.rarity}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
              Text(
                formatUsd(v.marketPrice),
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
