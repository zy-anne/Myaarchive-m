import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/app_color_palette.dart';
import '../../providers/app_providers.dart';
import '../../theme/colors.dart';

/// User settings, cloud sync status, library management, theme/content
/// preferences, and account options.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _tursoPingResult;
  String? _r2PingResult;
  bool _isTestingSync = false;

  Future<void> _testCloudSync() async {
    setState(() {
      _isTestingSync = true;
      _tursoPingResult = 'Testing connection...';
      _r2PingResult = 'Testing connection...';
    });

    try {
      final turso = ref.read(tursoClientProvider);
      final tRes = await turso.execute('SELECT 1 as ping');
      if (tRes.rows.isNotEmpty) {
        _tursoPingResult = 'Connected (Turso Hrana v2)';
      } else {
        _tursoPingResult = 'Failed to ping Turso';
      }
    } catch (e) {
      _tursoPingResult = 'Turso error: $e';
    }

    try {
      final r2 = ref.read(r2ServiceProvider);
      final testUrl = await r2.getDownloadUrl('test.jpg');
      if (testUrl.isNotEmpty) {
        _r2PingResult = 'Connected (Cloudflare R2)';
      } else {
        _r2PingResult = 'R2 signature failed';
      }
    } catch (e) {
      _r2PingResult = 'R2 error: $e';
    }

    if (mounted) {
      setState(() => _isTestingSync = false);
    }
  }

  void _showAddLibraryDialog() {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceLight,
        title: const Text('New Library Collection'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Library Name (e.g. Light Novels, Manga)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final user = ref.read(authStateProvider).value;
              if (user != null) {
                await ref
                    .read(dataLayerProvider)
                    .librariesCreate(ownerId: user.id, name: name);
                ref.invalidate(librariesProvider);
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(String userId) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceLight,
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password (min 4 chars)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(authServiceProvider).changePassword(
                      userId,
                      currentCtrl.text,
                      newCtrl.text,
                    );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password updated successfully!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPalette(AppColorPalette palette) async {
    ref.read(colorPaletteIdProvider.notifier).state = palette.id;
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      await ref
          .read(dataLayerProvider)
          .settingsSet(user.id, 'colorPaletteId', palette.id);
    }
  }

  Future<void> _toggleNsfw(bool val) async {
    ref.read(showNsfwProvider.notifier).state = val;
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      await ref
          .read(dataLayerProvider)
          .settingsSet(user.id, 'showNsfwContent', val ? '1' : '0');
    }
    ref.invalidate(seriesListProvider);
    ref.invalidate(allSeriesForStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Fire-and-forget: seeds colorPaletteIdProvider / showNsfwProvider from
    // persisted app_settings as soon as a user is available. Settings is
    // always mounted (home's IndexedStack keeps all 3 tabs alive), so this
    // runs early regardless of which tab is visible.
    ref.watch(themeInitProvider);

    final user = ref.watch(authStateProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final selectedPaletteId = ref.watch(colorPaletteIdProvider);
    final showNsfw = ref.watch(showNsfwProvider);
    final librariesAsync = ref.watch(librariesProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text(
          'Settings & Account',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // User Profile Card
          if (user != null)
            Card(
              color: AppColors.darkSurfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.darkBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          user.username.isNotEmpty
                              ? user.username[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.username,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'User ID: ${user.id.substring(0, 8)}...',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.darkTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Cloud Sync Section
          const Text(
            'CLOUD SYNC & DATABASE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.darkSurfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_sync_rounded,
                      color: AppColors.primaryLight),
                  title: const Text('Turso & R2 Connectivity'),
                  subtitle: Text(
                    _tursoPingResult == null
                        ? 'Tap to verify cloud sync'
                        : 'DB: $_tursoPingResult\nR2: $_r2PingResult',
                  ),
                  trailing: _isTestingSync
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ElevatedButton.icon(
                          onPressed: _testCloudSync,
                          icon: const Icon(Icons.network_check_rounded, size: 16),
                          label: const Text('Test'),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Libraries Management
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIBRARIES & COLLECTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.darkTextMuted,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, color: AppColors.primaryLight),
                onPressed: _showAddLibraryDialog,
              ),
            ],
          ),
          const SizedBox(height: 4),
          librariesAsync.when(
            data: (libs) => Column(
              children: libs.map((lib) {
                return Card(
                  color: AppColors.darkSurfaceLight,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.darkBorder),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.collections_bookmark_rounded,
                        color: AppColors.primaryLight),
                    title: Text(lib.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${lib.seriesCount} entries'),
                    trailing: libs.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () async {
                              await ref
                                  .read(dataLayerProvider)
                                  .librariesDelete(lib.id);
                              ref.invalidate(librariesProvider);
                            },
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            ),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 20),

          // ── Color Theme ──────────────────────────────────────────────
          const Text(
            'COLOR THEME',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Switch between Light Mode and Dark Mode reading palettes.',
            style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildThemePill(
                  label: 'DARK MODE',
                  selected: themeMode == ThemeMode.dark,
                  onTap: () =>
                      ref.read(themeModeProvider.notifier).state = ThemeMode.dark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildThemePill(
                  label: 'LIGHT MODE',
                  selected: themeMode == ThemeMode.light,
                  onTap: () =>
                      ref.read(themeModeProvider.notifier).state = ThemeMode.light,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Color Palette ────────────────────────────────────────────
          const Text(
            'COLOR PALETTE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick an accent palette — it applies to both Light and Dark Mode.',
            style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AppColorPalettes.all.map((palette) {
              return _buildPaletteCard(
                palette,
                palette.id == selectedPaletteId,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Content ──────────────────────────────────────────────────
          const Text(
            'CONTENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.darkSurfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppColors.darkBorder),
            ),
            child: SwitchListTile(
              title: const Text('Show NSFW Content'),
              subtitle: const Text(
                "When off, titles marked NSFW are hidden from your library "
                "entirely. This is separate from the NSFW filter in More "
                "Filters, which only searches within what's shown here.",
              ),
              value: showNsfw,
              activeColor: AppColors.primaryLight,
              onChanged: _toggleNsfw,
            ),
          ),
          const SizedBox(height: 24),

          // ── Reading Statuses ────────────────────────────────────────
          const Text(
            'READING STATUSES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.darkSurfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppColors.darkBorder),
            ),
            child: ListTile(
              leading:
                  const Icon(Icons.bookmark_outline_rounded, color: AppColors.primaryLight),
              title: const Text('Manage Statuses'),
              subtitle: const Text(
                'Add, rename, recolor, or delete the reading statuses used '
                'across your library.',
              ),
              trailing: OutlinedButton(
                onPressed: () => context.push('/settings/statuses'),
                child: const Text('Manage...'),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Tags ─────────────────────────────────────────────────────
          const Text(
            'TAGS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.darkSurfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppColors.darkBorder),
            ),
            child: ListTile(
              leading: const Icon(Icons.sell_outlined, color: AppColors.primaryLight),
              title: const Text('Manage Tags'),
              subtitle: const Text(
                'Rename, recolor, or delete tags — fix typos or clean up '
                'ones you no longer use. Deleting a tag removes it from '
                'every title currently using it.',
              ),
              trailing: OutlinedButton(
                onPressed: () => context.push('/settings/tags'),
                child: const Text('Manage...'),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Account Actions
          const Text(
            'ACCOUNT & SECURITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.darkSurfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                if (user != null) ...[
                  ListTile(
                    leading: const Icon(Icons.lock_reset_rounded),
                    title: const Text('Change Password'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => _showChangePasswordDialog(user.id),
                  ),
                  const Divider(height: 1, color: AppColors.darkBorder),
                ],
                ListTile(
                  leading:
                      const Icon(Icons.logout_rounded, color: AppColors.error),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(
                        color: AppColors.error, fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    await ref.read(authStateProvider.notifier).signOut();
                    if (context.mounted) {
                      context.go('/sign-in');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildThemePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.darkSurfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primaryLight : AppColors.darkBorder,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: selected ? Colors.white : AppColors.darkTextMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildPaletteCard(AppColorPalette palette, bool selected) {
    return GestureDetector(
      onTap: () => _selectPalette(palette),
      child: Container(
        width: 134,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryLight : AppColors.darkBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: palette.swatches
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration:
                              BoxDecoration(color: c, shape: BoxShape.circle),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              palette.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}