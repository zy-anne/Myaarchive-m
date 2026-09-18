import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../theme/colors.dart';
import '../../widgets/tag_chip.dart';

/// Categories, Genres, and User Tags overview screen.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(userTagsProvider);
    final genresAsync = ref.watch(allGenresProvider);
    final warningsAsync = ref.watch(userContentWarningsProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text(
          'Categories & Tags',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Genres Section
          Text(
            'GENRES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          genresAsync.when(
            data: (genres) => genres.isEmpty
                ? const Text('No genres found')
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: genres.map((g) => TagChip.fromGenre(g)).toList(),
                  ),
            loading: () => Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            ),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),

          // User Tags Section
          Text(
            'MY TAGS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          tagsAsync.when(
            data: (tags) => tags.isEmpty
                ? Text(
                    'No tags created yet. Tags are added when creating or editing books.',
                    style: TextStyle(color: AppColors.darkTextMuted, fontSize: 13),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.map((t) => TagChip.fromTag(t)).toList(),
                  ),
            loading: () => Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            ),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),

          // Content Warnings Section
          Text(
            'CONTENT WARNINGS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 8),
          warningsAsync.when(
            data: (warnings) => warnings.isEmpty
                ? Text(
                    'No content warnings created.',
                    style: TextStyle(color: AppColors.darkTextMuted, fontSize: 13),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: warnings
                        .map((w) => TagChip.fromWarning(w))
                        .toList(),
                  ),
            loading: () => Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            ),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}
