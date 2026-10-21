import 'package:flutter/material.dart';

/// Shows a standard "are you sure?" dialog for destructive actions.
/// Returns true only if the user explicitly confirms.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
