import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_color_palette.dart';
import 'providers/app_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MyaarchiveApp(),
    ),
  );
}

class MyaarchiveApp extends ConsumerWidget {
  const MyaarchiveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final palette = AppColorPalettes.byId(ref.watch(colorPaletteIdProvider));
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
    AppColors.setTheme(isDark: isDark, palette: palette);

    return MaterialApp.router(
      title: 'Myaarchive',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(palette),
      darkTheme: AppTheme.dark(palette),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final currentDark = Theme.of(context).brightness == Brightness.dark;
        AppColors.setTheme(isDark: currentDark, palette: palette);
        return child ?? const SizedBox.shrink();
      },
    );
  }
}