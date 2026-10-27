import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/util/ui/desktop_palette.dart';
import 'package:localsend_app/util/ui/dynamic_colors.dart';
import 'package:localsend_app/util/ui/semantic_colors.dart';
import 'package:localsend_app/widget/big_button.dart';

void main() {
  group('desktop palette theme integration', () {
    test('desktop palette overrides every color mode and host brightness', () {
      final palette = _darkPalette();
      final dynamicColors = DynamicColors(
        light: ColorScheme.fromSeed(seedColor: Colors.orange, brightness: Brightness.light),
        dark: ColorScheme.fromSeed(seedColor: Colors.orange, brightness: Brightness.dark),
      );

      for (final colorMode in ColorMode.values) {
        for (final hostBrightness in Brightness.values) {
          final theme = getTheme(
            colorMode,
            Colors.purple,
            hostBrightness,
            dynamicColors,
            desktopPalette: palette,
          );

          expect(theme.colorScheme.surface, palette.colorScheme.surface);
          expect(theme.colorScheme.primary, palette.colorScheme.primary);
          expect(theme.colorScheme.brightness, Brightness.dark);
          expect(theme.warningColor, palette.warning);
          expect(theme.successColor, palette.success);
        }
      }
    });

    test('system mode follows palette brightness while manual and fallback modes persist', () {
      final darkPalette = _darkPalette();
      final lightPalette = _lightPalette();

      expect(getEffectiveThemeMode(ThemeMode.system, ColorMode.system, darkPalette), ThemeMode.dark);
      expect(getEffectiveThemeMode(ThemeMode.system, ColorMode.system, lightPalette), ThemeMode.light);
      expect(getEffectiveThemeMode(ThemeMode.system, ColorMode.oled, lightPalette), ThemeMode.light);
      expect(getEffectiveThemeMode(ThemeMode.light, ColorMode.system, darkPalette), ThemeMode.light);
      expect(getEffectiveThemeMode(ThemeMode.dark, ColorMode.system, lightPalette), ThemeMode.dark);
      expect(getEffectiveThemeMode(ThemeMode.system, ColorMode.system, null), ThemeMode.system);
      expect(getEffectiveThemeMode(ThemeMode.system, ColorMode.oled, null), ThemeMode.dark);
      expect(getEffectiveThemeMode(ThemeMode.light, ColorMode.oled, null), ThemeMode.dark);
    });

    test('without a desktop palette existing generated themes and semantic fallbacks remain', () {
      final customTheme = getTheme(ColorMode.custom, Colors.deepPurple, Brightness.light, null);
      final dynamicColors = DynamicColors(
        light: ColorScheme.fromSeed(seedColor: Colors.orange, brightness: Brightness.light),
        dark: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      );
      final systemTheme = getTheme(ColorMode.system, Colors.teal, Brightness.dark, dynamicColors);

      expect(customTheme.colorScheme.brightness, Brightness.light);
      expect(customTheme.colorScheme.primary, isNot(Colors.teal));
      expect(customTheme.warningColor, Colors.orange);
      expect(customTheme.successColor, Colors.green);
      expect(systemTheme.colorScheme.brightness, Brightness.dark);
      expect(systemTheme.colorScheme.primary, dynamicColors.dark.primary);
      expect(systemTheme.extension<SemanticColors>(), isNull);
    });

    test('desktop roles feed text, input, button, and navigation theme defaults', () {
      final palette = _darkPalette();
      final theme = getTheme(ColorMode.custom, Colors.purple, Brightness.light, null, desktopPalette: palette);
      final scheme = theme.colorScheme;
      final navigation = theme.navigationBarTheme;
      final rail = theme.navigationRailTheme;
      final input = theme.inputDecorationTheme;

      expect(theme.textTheme.bodyLarge?.color, scheme.onSurface);
      expect(input.fillColor, scheme.secondaryContainer);
      expect((input.enabledBorder! as OutlineInputBorder).borderSide.color, scheme.outline);
      expect((input.focusedBorder! as OutlineInputBorder).borderSide.color, scheme.primary);
      expect(theme.elevatedButtonTheme.style!.foregroundColor!.resolve({}), scheme.primary);
      expect(navigation.backgroundColor, scheme.surfaceContainer);
      expect(navigation.indicatorColor, scheme.primaryContainer);
      expect(navigation.iconTheme!.resolve({WidgetState.selected})!.color, scheme.onPrimaryContainer);
      expect(navigation.iconTheme!.resolve({})!.color, scheme.onSurfaceVariant);
      expect(navigation.labelTextStyle!.resolve({})!.color, scheme.onSurface);
      expect(rail.backgroundColor, scheme.surfaceContainer);
      expect(rail.indicatorColor, scheme.primaryContainer);
      expect(rail.selectedIconTheme!.color, scheme.onPrimaryContainer);
      expect(rail.unselectedIconTheme!.color, scheme.onSurfaceVariant);
      expect(rail.selectedLabelTextStyle!.color, scheme.onSurface);
      expect(rail.unselectedLabelTextStyle!.color, scheme.onSurfaceVariant);
      expect(theme.warningColor, palette.warning);
      expect(theme.successColor, palette.success);
    });

    testWidgets('a real BigButton uses the palette and text field state survives a theme update', (tester) async {
      final darkPalette = _darkPalette();
      final lightPalette = _lightPalette();
      final darkTheme = getTheme(ColorMode.system, Colors.teal, Brightness.light, null, desktopPalette: darkPalette);
      final lightTheme = getTheme(ColorMode.system, Colors.teal, Brightness.dark, null, desktopPalette: lightPalette);

      await tester.pumpWidget(_themeSmokeApp(darkTheme));
      final field = find.byKey(const ValueKey('palette-text-field'));
      await tester.enterText(field, 'keep this text');

      var button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.style!.backgroundColor!.resolve({}), darkPalette.colorScheme.primary);
      expect(button.style!.foregroundColor!.resolve({}), darkPalette.colorScheme.onPrimary);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'keep this text');

      await tester.pumpWidget(_themeSmokeApp(lightTheme));
      await tester.pumpAndSettle();

      button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.style!.backgroundColor!.resolve({}), lightPalette.colorScheme.primary);
      expect(button.style!.foregroundColor!.resolve({}), lightPalette.colorScheme.onPrimary);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'keep this text');
    });
  });
}

Widget _themeSmokeApp(ThemeData theme) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TextField(key: ValueKey('palette-text-field')),
          BigButton(
            icon: Icons.send,
            label: 'Send',
            filled: true,
            onTap: () {},
          ),
        ],
      ),
    ),
  );
}

DesktopPalette _darkPalette() => DesktopPalette.parse('''
Singleton {
  property color background: "#121212"
  property color backgroundAlt: "#1c1c1c"
  property color backgroundGray: "#242424"
  property color foreground: "#f2f2f2"
  property color foregroundInactive: "#bdbdbd"
  property color primary: "#43a084"
  property color muted: "#bdbdbd"
  property color border: "#777777"
  property color secondary: "#58a8cf"
  property color success: "#4baf62"
  property color warning: "#f0af45"
  property color danger: "#ef6666"
}
''')!;

DesktopPalette _lightPalette() => DesktopPalette.parse('''
Singleton {
  property color background: "#f8f7f3"
  property color backgroundAlt: "#f0efea"
  property color backgroundGray: "#e6e5e0"
  property color foreground: "#222428"
  property color foregroundInactive: "#66686d"
  property color primary: "#177054"
  property color muted: "#66686d"
  property color border: "#777777"
  property color secondary: "#275792"
  property color success: "#286935"
  property color warning: "#864c00"
  property color danger: "#9c282c"
}
''')!;
