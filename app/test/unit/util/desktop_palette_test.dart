import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/util/ui/desktop_palette.dart';

void main() {
  group('DesktopPalette.parse', () {
    test('parses Qt rgba divisions and derives brightness from the palette', () {
      final palette = DesktopPalette.parse('''
pragma Singleton
Singleton {
  readonly property color background: Qt.rgba(26 / 255, 21 / 255, 21 / 255, 0.8)
  readonly property color backgroundAlt: "#241D1D"
  readonly property color backgroundGray: "#362A2A"
  readonly property color foreground: "#ffe9c7"
  readonly property color foregroundInactive: "#A89184"
  readonly property color primary: "#AE3F82"
  readonly property color muted: "#A89184"
  readonly property color border: "#7B3D79"
  readonly property color secondary: "#756D94"
  readonly property color success: "#959A6B"
  readonly property color warning: "#E39C45"
  readonly property color danger: "#F07342"
}
''');

      expect(palette, isNotNull);
      expect(palette!.colorScheme.brightness, Brightness.dark);
      expect(palette.colorScheme.surface, const Color.fromARGB(255, 26, 21, 21));
      expect(palette.colorScheme.surface.toARGB32() >> 24, 255);
    });

    test('parses shorthand and Qt ARGB colors, forces opacity, and resolves aliases', () {
      final palette = DesktopPalette.parse('''
Singleton {
  property color background: "#80112233"
  property color backgroundAlt: background
  property color backgroundGray: "#224"
  property color foreground: "#fff"
  property color primary: "#abc"
}
''');

      expect(palette, isNotNull);
      expect(palette!.colorScheme.surface, const Color.fromARGB(255, 0x11, 0x22, 0x33));
      expect(palette.colorScheme.surfaceContainerLow, isNot(palette.colorScheme.surface));
    });

    test('Akane ARGB and rgba backgrounds keep the same opaque RGB surface and readable text', () {
      final argbPalette = DesktopPalette.parse(_akaneQml('"#e00e1e36"'))!;
      final rgbaPalette = DesktopPalette.parse(_akaneQml('Qt.rgba(14/255,30/255,54/255,0.88)'))!;

      for (final palette in [argbPalette, rgbaPalette]) {
        final scheme = palette.colorScheme;
        final surfaces = [
          scheme.surface,
          scheme.surfaceContainerLowest,
          scheme.surfaceContainerLow,
          scheme.surfaceContainer,
          scheme.surfaceContainerHigh,
          scheme.surfaceContainerHighest,
        ];
        expect(scheme.surface, const Color(0xff0e1e36));
        expect(scheme.surface.toARGB32() >> 24, 255);
        for (final foreground in [scheme.onSurface, scheme.onSurfaceVariant, scheme.primary, scheme.secondary, scheme.tertiary, scheme.error]) {
          for (final surface in surfaces) {
            expect(_contrast(foreground, surface), greaterThanOrEqualTo(4.5));
          }
        }
      }
      expect(argbPalette.colorScheme.surface, rgbaPalette.colorScheme.surface);
    });

    test('rejects missing, malformed, and truncated core palette data', () {
      expect(DesktopPalette.parse('Singleton { property color background: "#000" }'), isNull);
      expect(
        DesktopPalette.parse('''
Singleton {
  property color background: "not a color"
  property color foreground: "#fff"
  property color primary: "#00f"
}
'''),
        isNull,
      );
      expect(
        DesktopPalette.parse('''
Singleton {
  property color background: "#000"
  property color foreground: "#fff"
  property color primary: "#00f"
'''),
        isNull,
      );
      expect(
        DesktopPalette.parse('''
Singleton {
  property color background: Qt.rgba(3, 0, 0, 1)
  property color foreground: "#fff"
  property color primary: "#00f"
}
'''),
        isNull,
      );
    });

    test('falls back for malformed optional roles', () {
      final palette = DesktopPalette.parse('''
Singleton {
  property color background: "#101010"
  property color backgroundAlt: "invalid"
  property color foreground: "#f0f0f0"
  property color primary: "#70c0a0"
}
''');

      expect(palette, isNotNull);
      expect(palette!.colorScheme.surface, const Color.fromARGB(255, 0x10, 0x10, 0x10));
    });

    test('corrects low contrast roles and keeps all text readable across surfaces', () {
      final palette = DesktopPalette.parse('''
Singleton {
  property color background: "#202020"
  property color backgroundAlt: background
  property color backgroundGray: background
  property color foreground: "#222222"
  property color foregroundInactive: "#333333"
  property color primary: "#202020"
  property color muted: "#222222"
  property color border: "#222222"
  property color secondary: "#202020"
  property color success: "#202020"
  property color warning: "#202020"
  property color danger: "#202020"
}
''');

      expect(palette, isNotNull);
      final scheme = palette!.colorScheme;
      final surfaces = _surfaces(scheme);
      for (final text in [
        scheme.onSurface,
        scheme.onSurfaceVariant,
        scheme.primary,
        scheme.secondary,
        scheme.tertiary,
        scheme.error,
        palette.warning,
        palette.success,
      ]) {
        for (final surface in surfaces) {
          expect(_contrast(text, surface), greaterThanOrEqualTo(4.5));
        }
      }
      expect(_contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onSecondary, scheme.secondary), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onTertiary, scheme.tertiary), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onError, scheme.error), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onPrimaryFixed, scheme.primaryFixed), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onPrimaryFixedVariant, scheme.primaryFixed), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onSecondaryFixed, scheme.secondaryFixed), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onSecondaryFixedVariant, scheme.secondaryFixed), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onTertiaryFixed, scheme.tertiaryFixed), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onTertiaryFixedVariant, scheme.tertiaryFixed), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onPrimaryContainer, scheme.primaryContainer), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onSecondaryContainer, scheme.secondaryContainer), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onTertiaryContainer, scheme.tertiaryContainer), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onErrorContainer, scheme.errorContainer), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onInverseSurface, scheme.inverseSurface), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.inversePrimary, scheme.inverseSurface), greaterThanOrEqualTo(4.5));
      for (final surface in surfaces) {
        expect(_contrast(scheme.outline, surface), greaterThanOrEqualTo(3));
        expect(_contrast(scheme.outlineVariant, surface), greaterThanOrEqualTo(3));
      }
      expect(scheme.surfaceContainerLowest, isNot(scheme.surfaceContainerHighest));
    });

    test('preserves usable authored colors and derives light mode from a light background', () {
      const background = Color.fromARGB(255, 0xf8, 0xf7, 0xf3);
      const foreground = Color.fromARGB(255, 0x22, 0x24, 0x28);
      const primary = Color.fromARGB(255, 0x17, 0x70, 0x54);
      const secondary = Color.fromARGB(255, 0x27, 0x57, 0x92);
      const success = Color.fromARGB(255, 0x28, 0x69, 0x35);
      const warning = Color.fromARGB(255, 0x86, 0x4c, 0x00);
      const danger = Color.fromARGB(255, 0x9c, 0x28, 0x2c);
      final palette = DesktopPalette.parse('''
Singleton {
  property color background: "#F8F7F3"
  property color backgroundAlt: "#F0EFEA"
  property color backgroundGray: "#E6E5E0"
  property color foreground: "#222428"
  property color primary: "#177054"
  property color secondary: "#275792"
  property color success: "#286935"
  property color warning: "#864C00"
  property color danger: "#9C282C"
}
''');

      expect(palette, isNotNull);
      expect(palette!.colorScheme.brightness, Brightness.light);
      expect(palette.colorScheme.surface, background);
      expect(palette.colorScheme.onSurface, foreground);
      expect(palette.colorScheme.primary, primary);
      expect(palette.colorScheme.secondary, secondary);
      expect(palette.colorScheme.surfaceTint, Colors.transparent);
      expect(palette.success, success);
      expect(palette.warning, warning);
      expect(palette.colorScheme.error, danger);
    });
  });
}

List<Color> _surfaces(ColorScheme scheme) => [
  scheme.surface,
  scheme.surfaceDim,
  scheme.surfaceBright,
  scheme.surfaceContainerLowest,
  scheme.surfaceContainerLow,
  scheme.surfaceContainer,
  scheme.surfaceContainerHigh,
  scheme.surfaceContainerHighest,
];

double _contrast(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker = firstLuminance < secondLuminance ? firstLuminance : secondLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

String _akaneQml(String background) =>
    '''
pragma Singleton
Singleton {
  readonly property color background: $background
  readonly property color backgroundAlt: "#0E1E36"
  readonly property color backgroundGray: "#2a3a56"
  readonly property color foreground: "#f4b999"
  readonly property color foregroundInactive: "#fa7e75"
  readonly property color primary: "#9279aa"
  readonly property color muted: "#574f72"
  readonly property color border: "#9279aa"
  readonly property color secondary: "#c85670"
  readonly property color success: "#be6f76"
  readonly property color warning: "#f4b999"
  readonly property color danger: "#d2495b"
}
''';
