import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_controller.dart';
import '../../data/local/database.dart';
import '../../providers.dart';
import '../../util/format.dart';
import '../collection/add_to_collection_sheet.dart';
import 'widgets/card_thumb.dart';

/// Per-card detail: card stats + every printing (variant) with its price.
final _cardProvider = FutureProvider.family<CatalogCard?, String>(
  (ref, cardId) => ref.watch(catalogRepositoryProvider).cardById(cardId),
);
final _variantsProvider = StreamProvider.family<List<CatalogVariant>, String>(
  (ref, cardId) => ref.watch(catalogRepositoryProvider).watchVariantsForCard(cardId),
);

class CardDetailScreen extends ConsumerWidget {
  const CardDetailScreen({super.key, required this.cardId});
  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(_cardProvider(cardId));
    final variants = ref.watch(_variantsProvider(cardId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(card.asData?.value?.name ?? 'Card'),
      ),
      body: card.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (c) {
          if (c == null) return const Center(child: Text('Card not found.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CardHeader(card: c),
              const SizedBox(height: 20),
              Text('Printings', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              variants.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (vs) => Column(
                  children: [for (final v in vs) _VariantRow(variant: v, cardName: c.name)],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.card});
  final CatalogCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = card.colors.isEmpty ? const <String>[] : card.colors.split(',');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 6, children: [
          _Pill('${card.cardCode} · ${card.setCode}'),
          _Pill(card.type),
          for (final c in colors) _Pill(c),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 4, children: [
          if (card.cost != null) _Stat('Cost', '${card.cost}'),
          if (card.power != null) _Stat('Power', '${card.power}'),
          if (card.counter != null) _Stat('Counter', '${card.counter}'),
          if (card.attribute != null) _Stat('Attribute', card.attribute!),
          if (card.family != null) _Stat('Type', card.family!),
        ]),
        if (card.abilityText != null) ...[
          const SizedBox(height: 12),
          Text(card.abilityText!, style: theme.textTheme.bodyMedium),
        ],
        if (card.triggerText != null) ...[
          const SizedBox(height: 8),
          Text('Trigger: ${card.triggerText!}',
              style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }
}

class _VariantRow extends ConsumerWidget {
  const _VariantRow({required this.variant, required this.cardName});
  final CatalogVariant variant;
  final String cardName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authed = ref.watch(authControllerProvider).isAuthenticated;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 78,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CardThumb(thumbPath: variant.thumbUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(variant.variantId,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    [
                      if (variant.isAltArt) variant.variantLabel ?? 'Alt art' else 'Base',
                      if (variant.rarity != null) variant.rarity!,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            Text(
              formatUsd(variant.marketPrice),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            IconButton(
              tooltip: authed ? 'Add to collection' : 'Sign in to add',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                if (authed) {
                  AddToCollectionSheet.show(context,
                      variantId: variant.variantId, title: '$cardName · ${variant.variantId}');
                } else {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}
