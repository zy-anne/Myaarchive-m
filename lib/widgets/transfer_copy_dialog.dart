import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/series.dart';
import '../providers/app_providers.dart';
import '../theme/app_palette.dart';

/// Bottom sheet letting the user Transfer (move) or Copy a title into a
/// different library. Transfer keeps a single copy and just re-homes it;
/// Copy duplicates it, with checkboxes for which attached data to bring
/// along (volumes, characters, gallery, files/links).
Future<void> showTransferCopyDialog(
  BuildContext context,
  WidgetRef ref,
  Series series,
  AppPalette palette,
) async {
  final libraries = ref.read(librariesProvider).valueOrNull ?? [];
  final otherLibraries =
      libraries.where((l) => l.id != series.libraryId).toList();

  if (otherLibraries.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'Add another library first to transfer or copy into it.'),
        backgroundColor: palette.danger,
      ),
    );
    return;
  }

  int targetLibraryId = otherLibraries.first.id;
  bool isCopy = false;
  bool includeVolumes = true;
  bool includeCharacters = true;
  bool includeGallery = true;
  bool includeAttachments = true;
  bool isWorking = false;

  await showModalBottomSheet(
    context: context,
    backgroundColor: palette.surfaceLight,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: palette.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Move "${series.title}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: palette.textMain,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Transfer vs Copy toggle
                  Row(
                    children: [
                      Expanded(
                        child: _ModePill(
                          label: 'Transfer',
                          selected: !isCopy,
                          palette: palette,
                          onTap: () => setSheetState(() => isCopy = false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ModePill(
                          label: 'Copy',
                          selected: isCopy,
                          palette: palette,
                          onTap: () => setSheetState(() => isCopy = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'DESTINATION LIBRARY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: targetLibraryId,
                    dropdownColor: palette.surfaceLight,
                    decoration: const InputDecoration(isDense: true),
                    items: otherLibraries
                        .map((l) => DropdownMenuItem(
                              value: l.id,
                              child: Text(l.name),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => targetLibraryId = val);
                      }
                    },
                  ),

                  if (isCopy) ...[
                    const SizedBox(height: 18),
                    Text(
                      'INCLUDE IN COPY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: palette.textSecondary,
                      ),
                    ),
                    CheckboxListTile(
                      value: includeVolumes,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Volumes'),
                      onChanged: (v) =>
                          setSheetState(() => includeVolumes = v ?? true),
                    ),
                    CheckboxListTile(
                      value: includeCharacters,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Characters & Relationships'),
                      onChanged: (v) =>
                          setSheetState(() => includeCharacters = v ?? true),
                    ),
                    CheckboxListTile(
                      value: includeGallery,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Gallery Images'),
                      onChanged: (v) =>
                          setSheetState(() => includeGallery = v ?? true),
                    ),
                    CheckboxListTile(
                      value: includeAttachments,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Files & Links'),
                      onChanged: (v) =>
                          setSheetState(() => includeAttachments = v ?? true),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: isWorking
                          ? null
                          : () async {
                              setSheetState(() => isWorking = true);
                              final dataLayer = ref.read(dataLayerProvider);
                              final navigator = Navigator.of(ctx);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                if (isCopy) {
                                  await dataLayer.seriesCopyTo(
                                    series.id,
                                    targetLibraryId,
                                    includeVolumes: includeVolumes,
                                    includeCharacters: includeCharacters,
                                    includeGallery: includeGallery,
                                    includeAttachments: includeAttachments,
                                  );
                                } else {
                                  await dataLayer.seriesTransferTo(
                                    series.id,
                                    targetLibraryId,
                                  );
                                }
                                ref.invalidate(seriesListProvider);
                                ref.invalidate(librariesProvider);
                                ref.invalidate(
                                    seriesDetailProvider(series.id));
                                navigator.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(isCopy
                                        ? 'Copied "${series.title}"'
                                        : 'Moved "${series.title}"'),
                                    backgroundColor: palette.primary,
                                  ),
                                );
                              } catch (e) {
                                setSheetState(() => isWorking = false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Failed: $e'),
                                    backgroundColor: palette.danger,
                                  ),
                                );
                              }
                            },
                      child: isWorking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isCopy ? 'Copy Title' : 'Move Title'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _ModePill extends StatelessWidget {
  final String label;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  const _ModePill({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.primary : palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? palette.accent : palette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: selected ? palette.onSolid : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}