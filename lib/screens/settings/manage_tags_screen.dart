import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/metadata.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_palette.dart';

/// Rename, recolor, or delete tags — fix typos or clean up ones no longer
/// used. Deleting a tag removes it from every title currently using it.
class ManageTagsScreen extends ConsumerWidget {
  const ManageTagsScreen({super.key});

  void _showEditDialog(BuildContext context, WidgetRef ref, Tag tag, AppPalette palette) {
    final nameCtrl = TextEditingController(text: tag.name);
    Color selectedColor = tag.parsedColor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: palette.surfaceLight,
            title: const Text('Edit Tag'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: palette.textMain),
                    decoration: const InputDecoration(labelText: 'Tag Name'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Color',
                    style: TextStyle(fontSize: 12, color: palette.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: palette.tagPalette.map((c) {
                      final isSelected = c.toARGB32() == selectedColor.toARGB32();
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: palette.primary),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final colorHex =
                      '#${selectedColor.toARGB32().toRadixString(16).substring(2)}';
                  final updated = Tag(
                    id: tag.id,
                    ownerId: tag.ownerId,
                    name: name,
                    color: colorHex,
                  );
                  await ref.read(dataLayerProvider).tagsUpdate(updated);
                  ref.invalidate(userTagsProvider);
                  ref.invalidate(seriesListProvider);
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Tag tag, AppPalette palette) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
        title: const Text('Delete Tag?'),
        content: Text(
          'Delete "${tag.name}"? This removes it from every title currently using it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(dataLayerProvider).tagsDelete(tag.id);
      ref.invalidate(userTagsProvider);
      ref.invalidate(seriesListProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tagsAsync = ref.watch(userTagsProvider);

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: const Text(
          'Manage Tags',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
      ),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No tags yet. Tags are created when you add one while '
                  'creating or editing a book.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tags.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tag = tags[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: palette.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: tag.parsedColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tag.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: palette.textMain,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: palette.textSecondary,
                      onPressed: () => _showEditDialog(context, ref, tag, palette),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: palette.textSecondary,
                      onPressed: () => _confirmDelete(context, ref, tag, palette),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: palette.accent),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}