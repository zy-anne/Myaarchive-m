import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_color_palette.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_palette.dart';

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

  void _showAddLibraryDialog(AppPalette palette) {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
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
              final navigator = Navigator.of(ctx);
              if (user != null) {
                await ref
                    .read(dataLayerProvider)
                    .librariesCreate(ownerId: user.id, name: name);
                ref.invalidate(librariesProvider);
              }
              if (mounted) navigator.pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(String userId, AppPalette palette) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
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
              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(authServiceProvider).changePassword(
                      userId,
                      currentCtrl.text,
                      newCtrl.text,
                    );
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Password updated successfully!'),
                      backgroundColor: palette.primary,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: palette.danger,
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

  Future<void> _selectThemeMode(ThemeMode mode) async {
    ref.read(themeModeProvider.notifier).state = mode;
    final modeStr = mode == ThemeMode.light ? 'light' : 'dark';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('myaarchive_theme_mode', modeStr);
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        await ref
            .read(dataLayerProvider)
            .settingsSet(user.id, 'themeMode', modeStr);
      }
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  Future<void> _selectPalette(AppColorPalette palette) async {
    ref.read(colorPaletteIdProvider.notifier).state = palette.id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('myaarchive_color_palette_id', palette.id);
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        await ref
            .read(dataLayerProvider)
            .settingsSet(user.id, 'colorPaletteId', palette.id);
      }
    } catch (e) {
      debugPrint('Error saving color palette: $e');
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

    final palette = context.palette;

    final user = ref.watch(authStateProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final selectedPaletteId = ref.watch(colorPaletteIdProvider);
    final showNsfw = ref.watch(showNsfwProvider);
    final librariesAsync = ref.watch(librariesProvider);

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: const Text('Settings & Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // User Profile Card
          if (user != null)
            Card(
              color: palette.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: palette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [palette.primary, palette.accent],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          user.username.isNotEmpty
                              ? user.username[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: palette.onSolid,
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
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: palette.textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'User ID: ${user.id.substring(0, 8)}...',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: palette.textSecondary,
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
          _buildSectionHeader('CLOUD SYNC & DATABASE', palette),
          const SizedBox(height: 8),
          Card(
            color: palette.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: palette.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.cloud_sync_rounded,
                      color: palette.accent),
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
              _buildSectionHeader('LIBRARIES & COLLECTIONS', palette),
              IconButton(
                icon: Icon(Icons.add_rounded, color: palette.accent),
                onPressed: () => _showAddLibraryDialog(palette),
              ),
            ],
          ),
          _buildSectionDescription(
            'Drag the handle to reorder — this is the order libraries appear in throughout the app.',
            palette,
          ),
          const SizedBox(height: 8),
          librariesAsync.when(
            data: (libs) => ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: libs.length,
              onReorderItem: (oldIndex, newIndex) async {
                // onReorderItem's newIndex already accounts for the removed
                // item at oldIndex, unlike the deprecated onReorder — so no
                // manual adjustment is needed here.
                final reordered = List.of(libs);
                final moved = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, moved);
                await ref
                    .read(dataLayerProvider)
                    .librariesReorder(reordered.map((l) => l.id).toList());
                ref.invalidate(librariesProvider);
              },
              itemBuilder: (context, index) {
                final lib = libs[index];
                return Card(
                  key: ValueKey(lib.id),
                  color: palette.surfaceLight,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: palette.border),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.collections_bookmark_rounded,
                        color: palette.accent),
                    title: Text(lib.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${lib.seriesCount} entries'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (libs.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () async {
                              await ref
                                  .read(dataLayerProvider)
                                  .librariesDelete(lib.id);
                              ref.invalidate(librariesProvider);
                            },
                          ),
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Icon(
                              Icons.drag_handle_rounded,
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            loading: () => Center(
              child: CircularProgressIndicator(color: palette.accent),
            ),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 20),

          // ── Color Theme ──────────────────────────────────────────────
          _buildSectionHeader('COLOR THEME', palette),
          _buildSectionDescription(
            'Switch between Light Mode and Dark Mode reading palettes.',
            palette,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildThemePill(
                  label: 'DARK MODE',
                  selected: themeMode == ThemeMode.dark,
                  palette: palette,
                  onTap: () => _selectThemeMode(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildThemePill(
                  label: 'LIGHT MODE',
                  selected: themeMode == ThemeMode.light,
                  palette: palette,
                  onTap: () => _selectThemeMode(ThemeMode.light),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Color Palette ────────────────────────────────────────────
          _buildSectionHeader('COLOR PALETTE', palette),
          _buildSectionDescription(
            'Pick an accent palette — it applies to both Light and Dark Mode.',
            palette,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AppColorPalettes.all.map((p) {
              return _buildPaletteCard(
                p,
                p.id == selectedPaletteId,
                palette,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Content ──────────────────────────────────────────────────
          _buildSectionHeader('CONTENT', palette),
          const SizedBox(height: 8),
          Card(
            color: palette.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: palette.border),
            ),
            child: SwitchListTile(
              title: const Text('Show NSFW Content'),
              subtitle: const Text(
                "When off, titles marked NSFW are hidden from your library "
                "entirely. This is separate from the NSFW filter in More "
                "Filters, which only searches within what's shown here.",
              ),
              value: showNsfw,
              activeThumbColor: palette.accent,
              onChanged: _toggleNsfw,
            ),
          ),
          const SizedBox(height: 24),

          // ── Reading Statuses ────────────────────────────────────────
          _buildSectionHeader('READING STATUSES', palette),
          const SizedBox(height: 8),
          Card(
            color: palette.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: palette.border),
            ),
            child: ListTile(
              leading:
                  Icon(Icons.bookmark_outline_rounded, color: palette.accent),
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
          _buildSectionHeader('TAGS', palette),
          const SizedBox(height: 8),
          Card(
            color: palette.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: palette.border),
            ),
            child: ListTile(
              leading: Icon(Icons.sell_outlined, color: palette.accent),
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
          _buildSectionHeader('ACCOUNT & SECURITY', palette),
          const SizedBox(height: 8),
          Card(
            color: palette.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: palette.border),
            ),
            child: Column(
              children: [
                if (user != null) ...[
                  ListTile(
                    leading: const Icon(Icons.lock_reset_rounded),
                    title: const Text('Change Password'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => _showChangePasswordDialog(user.id, palette),
                  ),
                  Divider(height: 1, color: palette.border),
                ],
                ListTile(
                  leading:
                      Icon(Icons.logout_rounded, color: palette.danger),
                  title: Text(
                    'Sign Out',
                    style: TextStyle(
                        color: palette.danger, fontWeight: FontWeight.bold),
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

  Widget _buildSectionHeader(String title, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: palette.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSectionDescription(String description, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        description,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: palette.textSecondary,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildThemePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required AppPalette palette,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.primary : palette.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? palette.accent : palette.border,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: selected ? palette.onSolid : palette.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPaletteCard(AppColorPalette p, bool selected, AppPalette palette) {
    return GestureDetector(
      onTap: () => _selectPalette(p),
      child: Container(
        width: 134,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? palette.accent : palette.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: p.swatches
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
              p.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}