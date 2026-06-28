import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/collection_controller.dart';

const kConditions = ['NM', 'LP', 'MP', 'HP', 'DMG'];

/// Sheet to add a specific variant to the collection with a chosen condition.
class AddToCollectionSheet extends ConsumerStatefulWidget {
  const AddToCollectionSheet({super.key, required this.variantId, required this.title});
  final String variantId;
  final String title;

  static Future<void> show(BuildContext context, {required String variantId, required String title}) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => AddToCollectionSheet(variantId: variantId, title: title),
    );
  }

  @override
  ConsumerState<AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<AddToCollectionSheet> {
  String _condition = 'NM';
  bool _busy = false;

  Future<void> _add() async {
    setState(() => _busy = true);
    await ref.read(collectionActionsProvider).add(widget.variantId, condition: _condition);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${widget.variantId} ($_condition)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add to collection', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(widget.title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text('Condition', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final c in kConditions)
                  ChoiceChip(
                    label: Text(c),
                    selected: _condition == c,
                    onSelected: (_) => setState(() => _condition = c),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
