import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/reading_status_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_palette.dart';

/// Add, rename, recolor, or delete the reading statuses used across your
/// library. Renaming cascades onto every title currently using that
/// status; deleting moves those titles to "Planning" instead of leaving
/// them blank.
class ManageStatusesScreen extends ConsumerWidget {
  const ManageStatusesScreen({super.key});

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    String ownerId,
    AppPalette palette, {
    ReadingStatusItem? existing,
  }) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    Color selectedColor = existing?.parsedColor ?? palette.tagPalette.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: palette.surfaceLight,
            title: Text(existing == null ? 'New Status' : 'Edit Status'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: palette.textMain),
                    decoration: const InputDecoration(labelText: 'Status Name'),
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
                  final dataLayer = ref.read(dataLayerProvider);
                  if (existing == null) {
                    await dataLayer.statusesCreate(ownerId, name, colorHex);
                  } else {
                    await dataLayer.statusesUpdate(
                      existing.copyWith(name: name, color: colorHex),
                      previousName: existing.name,
                    );
                  }
                  ref.invalidate(readingStatusesProvider);
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

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String ownerId,
    ReadingStatusItem status,
    AppPalette palette,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
        title: const Text('Delete Status?'),
        content: Text(
          'Delete "${status.name}"? Titles using this status will be moved to "Planning".',
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
      await ref
          .read(dataLayerProvider)
          .statusesDelete(status.id, status.name, ownerId);
      ref.invalidate(readingStatusesProvider);
      ref.invalidate(seriesListProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final user = ref.watch(authStateProvider).value;
    final statusesAsync = ref.watch(readingStatusesProvider);

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: const Text('Manage Statuses'),
      ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton(
              backgroundColor: palette.primary,
              foregroundColor: palette.onSolid,
              onPressed: () => _showEditDialog(context, ref, user.id, palette),
              child: const Icon(Icons.add_rounded),
            ),
      body: user == null
          ? const SizedBox.shrink()
          : statusesAsync.when(
              data: (statuses) {
                if (statuses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No statuses yet. Tap + to add one.',
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: statuses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final status = statuses[index];
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
                              color: status.parsedColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              status.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: palette.textMain,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: palette.textSecondary,
                            onPressed: () => _showEditDialog(
                              context,
                              ref,
                              user.id,
                              palette,
                              existing: status,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: palette.textSecondary,
                            onPressed: () =>
                                _confirmDelete(context, ref, user.id, status, palette),
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