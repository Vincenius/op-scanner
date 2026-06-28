import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../util/format.dart';
import '../catalog/widgets/card_thumb.dart';
import 'share_controller.dart';

/// Public, read-only view of a shared collection (no auth required).
class PublicCollectionScreen extends ConsumerWidget {
  const PublicCollectionScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publicCollectionProvider(slug));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Shared collection'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text("This collection isn't available. The link may be wrong or sharing was turned off.",
                textAlign: TextAlign.center),
          ),
        ),
        data: (data) {
          final summary = data['summary'] as Map<String, dynamic>;
          final items = (data['items'] as List).cast<Map<String, dynamic>>();
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${summary['entries']} entries · ${summary['copies']} cards'),
                    Text('Value ${formatUsd((summary['value'] as num).toDouble())}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('This collection is empty.'))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) => _PublicTile(item: items[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PublicTile extends StatelessWidget {
  const _PublicTile({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = (item['tags'] as List).cast<String>();
    final price = (item['marketPrice'] as num?)?.toDouble();
    return ListTile(
      leading: SizedBox(
        width: 36,
        height: 50,
        child: ClipRRect(borderRadius: BorderRadius.circular(4), child: CardThumb(thumbPath: item['thumbUrl'] as String)),
      ),
      title: Text(item['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${item['variantId']} · ${item['condition']}'
        '${(item['isAltArt'] as bool) ? ' · ${item['variantLabel'] ?? 'Alt'}' : ''}'
        '${tags.isNotEmpty ? ' · ${tags.join(', ')}' : ''}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${item['quantity']}×', style: theme.textTheme.titleMedium),
          const SizedBox(width: 10),
          Text(formatUsd(price), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
