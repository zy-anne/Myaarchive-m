import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/relationship.dart';
import '../theme/app_palette.dart';
import 'relationship_style.dart';

/// Opens the create/edit bottom sheet for a relationship.
///
/// [existing] == null means "add"; otherwise the sheet edits it and shows a
/// Delete button (when [onDelete] is provided). [onSave] receives a draft
/// `Relationship` (id 0 for new) and should persist it; the sheet closes
/// itself once [onSave] / [onDelete] complete without throwing.
Future<void> showRelationshipEditor({
  required BuildContext context,
  required AppPalette palette,
  required List<Character> characters,
  Relationship? existing,
  required Future<void> Function(Relationship draft) onSave,
  Future<void> Function()? onDelete,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: palette.surfaceLight,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _RelationshipEditorSheet(
      palette: palette,
      characters: characters,
      existing: existing,
      onSave: onSave,
      onDelete: onDelete,
    ),
  );
}

class _RelationshipEditorSheet extends StatefulWidget {
  final AppPalette palette;
  final List<Character> characters;
  final Relationship? existing;
  final Future<void> Function(Relationship draft) onSave;
  final Future<void> Function()? onDelete;

  const _RelationshipEditorSheet({
    required this.palette,
    required this.characters,
    required this.existing,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_RelationshipEditorSheet> createState() =>
      _RelationshipEditorSheetState();
}

class _RelationshipEditorSheetState extends State<_RelationshipEditorSheet> {
  late int? _fromId;
  late int? _toId;
  late TextEditingController _typeCtrl;
  late TextEditingController _labelCtrl;
  late TextEditingController _notesCtrl;
  late bool _bidirectional;

  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final chars = widget.characters;
    final ex = widget.existing;

    bool has(int? id) => id != null && chars.any((c) => c.id == id);

    _fromId = has(ex?.fromCharacterId)
        ? ex!.fromCharacterId
        : (chars.isNotEmpty ? chars[0].id : null);
    _toId = has(ex?.toCharacterId)
        ? ex!.toCharacterId
        : (chars.length > 1 ? chars[1].id : null);

    _typeCtrl = TextEditingController(text: ex?.type ?? 'Friend');
    _labelCtrl = TextEditingController(text: ex?.label ?? '');
    _notesCtrl = TextEditingController(text: ex?.notes ?? '');
    _bidirectional = ex?.isBidirectional ?? true;
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _labelCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _nameOf(int? id) {
    if (id == null) return '?';
    for (final c in widget.characters) {
      if (c.id == id) return c.name;
    }
    return '?';
  }

  Future<void> _save() async {
    final type = _typeCtrl.text.trim();
    if (_fromId == null || _toId == null) {
      setState(() => _error = 'Pick two characters.');
      return;
    }
    if (_fromId == _toId) {
      setState(() => _error = 'Pick two different characters.');
      return;
    }
    if (type.isEmpty) {
      setState(() => _error = 'Enter a relationship type.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    String? orNull(String s) => s.trim().isEmpty ? null : s.trim();

    try {
      await widget.onSave(Relationship(
        id: widget.existing?.id ?? 0,
        fromCharacterId: _fromId!,
        toCharacterId: _toId!,
        type: type,
        label: orNull(_labelCtrl.text),
        isBidirectional: _bidirectional,
        notes: orNull(_notesCtrl.text),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Failed to save: $e';
        });
      }
    }
  }

  Future<void> _delete() async {
    final palette = widget.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
        title: const Text('Delete Relationship?'),
        content: Text(
          'Remove the relationship between ${_nameOf(_fromId)} and ${_nameOf(_toId)}?',
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
    if (confirmed != true || widget.onDelete == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onDelete!();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Failed to delete: $e';
        });
      }
    }
  }

  Widget _characterPicker(
    String label,
    int? value,
    ValueChanged<int?> onChanged,
  ) {
    final palette = widget.palette;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: palette.surfaceLight,
          style: TextStyle(fontSize: 13, color: palette.textMain),
          items: widget.characters
              .map((c) => DropdownMenuItem<int>(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: _busy ? null : onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final typeText = _typeCtrl.text.trim().toLowerCase();
    final style = relationshipStyleFor(_typeCtrl.text, palette);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
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
              _isEditing ? 'Edit Relationship' : 'Add Relationship',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: palette.textMain,
              ),
            ),
            const SizedBox(height: 16),

            // From / To
            Row(
              children: [
                Expanded(
                  child: _characterPicker(
                    'From',
                    _fromId,
                    (v) => setState(() => _fromId = v),
                  ),
                ),
                IconButton(
                  tooltip: 'Swap direction',
                  icon: Icon(Icons.swap_horiz_rounded, color: palette.accent),
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            final tmp = _fromId;
                            _fromId = _toId;
                            _toId = tmp;
                          }),
                ),
                Expanded(
                  child: _characterPicker(
                    'To',
                    _toId,
                    (v) => setState(() => _toId = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type
            Row(
              children: [
                Icon(style.icon, size: 16, color: style.color),
                const SizedBox(width: 6),
                Text(
                  'TYPE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: kSuggestedRelationshipTypes.map((t) {
                final selected = typeText == t.toLowerCase();
                return ChoiceChip(
                  label: Text(
                    t,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? palette.onSolid : palette.textSecondary,
                    ),
                  ),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: palette.primary,
                  backgroundColor: palette.surface,
                  onSelected:
                      _busy ? null : (_) => setState(() => _typeCtrl.text = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _typeCtrl,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Type (or type your own)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _labelCtrl,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Custom label (optional)',
                hintText: 'e.g. Childhood friend',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Direction
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mutual relationship'),
              subtitle: Text(
                _bidirectional
                    ? 'Applies both ways.'
                    : 'One-way: ${_nameOf(_fromId)} → ${_nameOf(_toId)}',
              ),
              value: _bidirectional,
              activeThumbColor: palette.accent,
              onChanged:
                  _busy ? null : (v) => setState(() => _bidirectional = v),
            ),

            TextField(
              controller: _notesCtrl,
              enabled: !_busy,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                alignLabelWithHint: true,
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(fontSize: 12, color: palette.danger),
              ),
            ],
            const SizedBox(height: 18),

            Row(
              children: [
                if (_isEditing && widget.onDelete != null) ...[
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _busy ? null : _delete,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: palette.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Tooltip(
                        message: 'Delete relationship',
                        child: Icon(Icons.delete_outline,
                            size: 20, color: palette.danger),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onSolid,
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Save Changes' : 'Add Relationship'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}