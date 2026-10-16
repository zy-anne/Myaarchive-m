import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/metadata.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_palette.dart';

/// Rename or delete content warnings — fix typos or clean up ones no longer
/// used. Deleting a warning removes it from every title currently using it.
class ManageWarningsScreen extends ConsumerWidget {
  const ManageWarningsScreen({super.key});

  void _showRenameDialog(
      BuildContext context, WidgetRef ref, ContentWarning warning, AppPalette palette) {
    final nameCtrl = TextEditingController(text: warning.name);
    String? error;
    var busy = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: palette.surfaceLight,
          title: const Text('Rename Warning'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: TextStyle(color: palette.textMain),
                decoration: InputDecoration(
                  labelText: 'Warning Name',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        setDialog(() => error = 'Name is required');
                        return;
                      }
                      if (name == warning.name) {
                        Navigator.pop(ctx);
                        return;
                      }
                      final navigator = Navigator.of(ctx);
                      setDialog(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(dataLayerProvider)
                            .contentWarningsRename(warning.id, name);
                        ref.invalidate(userContentWarningsProvider);
                        ref.invalidate(seriesListProvider);
                        if (ctx.mounted) navigator.pop();
                      } catch (e) {
                        // e.g. a warning with that name already exists.
                        if (ctx.mounted) {
                          setDialog(() {
                            busy = false;
                            error = e.toString().replaceFirst(RegExp(r'^\w*Exception: '), '');
                          });
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, ContentWarning warning, AppPalette palette) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
        title: const Text('Delete Warning?'),
        content: Text(
          'Delete "${warning.name}"? This removes it from every title currently using it.',
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
    if (confirmed != true) return;
    try {
      await ref.read(dataLayerProvider).contentWarningsDelete(warning.id);
      ref.invalidate(userContentWarningsProvider);
      ref.invalidate(seriesListProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't delete: $e")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final warningsAsync = ref.watch(userContentWarningsProvider);

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(title: const Text('Manage Content Warnings')),
      body: warningsAsync.when(
        data: (warnings) {
          if (warnings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No content warnings yet. They are created when you add one '
                  'while creating or editing a book.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: warnings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final warning = warnings[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: palette.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: palette.danger),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        warning.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: palette.textMain,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: palette.textSecondary,
                      tooltip: 'Rename',
                      onPressed: () => _showRenameDialog(context, ref, warning, palette),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: palette.textSecondary,
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(context, ref, warning, palette),
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
