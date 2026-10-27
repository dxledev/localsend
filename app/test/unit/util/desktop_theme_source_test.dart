import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/util/native/desktop_theme_source.dart';
import 'package:path/path.dart' as path;

void main() {
  group('DesktopThemeSource', () {
    late _ThemeFixture fixture;

    setUp(() async {
      fixture = await _ThemeFixture.create();
    });

    tearDown(() async {
      await fixture.dispose();
    });

    test('tracks a changed current target while the selector still points to current', () async {
      await fixture.writeTheme('static-a', '#101010');
      await fixture.writeTheme('static-b', '#202020');
      await fixture.link('static-a', 'current');
      await fixture.link('current', '.caelestia-use');
      final source = fixture.createSource();
      await fixture.startAndWait(source, '#101010');

      await fixture.replaceLink('static-b', 'current');

      await fixture.waitForPalette(source, '#202020');
      expect(await Link(fixture.selectorPath).target(), 'current');
    });

    test('follows Waybar current, Noctalia, Caelestia, and static restoration handoffs', () async {
      await fixture.writeTheme('static-a', '#101010');
      await fixture.writeTheme('static-b', '#202020');
      await fixture.writeTheme('.dynamic/caelestia', '#303030');
      await fixture.writeTheme('.dynamic/noctalia', '#404040');
      await fixture.link('static-a', 'current');
      final source = fixture.createSource();
      await fixture.startAndWait(source, '#101010');

      await fixture.replaceLink('.dynamic/noctalia', '.caelestia-use');
      await fixture.waitForPalette(source, '#404040');
      await fixture.replaceLink('.dynamic/caelestia', '.caelestia-use');
      await fixture.waitForPalette(source, '#303030');
      await fixture.replaceLink('current', '.caelestia-use');
      await fixture.waitForPalette(source, '#101010');

      await fixture.replaceLink('static-b', 'current');
      await fixture.waitForPalette(source, '#202020');
      await fixture.replaceLink('.dynamic/caelestia', '.caelestia-use');
      await fixture.waitForPalette(source, '#303030');
      await fixture.replaceLink('current', '.caelestia-use');
      await fixture.waitForPalette(source, '#202020');
      await fixture.replaceLink('.dynamic/noctalia', '.caelestia-use');
      await fixture.waitForPalette(source, '#404040');
      await fixture.replaceLink('current', '.caelestia-use');
      await fixture.waitForPalette(source, '#202020');
    });

    test('rearms after the selected provider directory is atomically replaced', () async {
      await fixture.writeTheme('.dynamic/provider', '#303030');
      await fixture.link('.dynamic/provider', '.caelestia-use');
      final source = fixture.createSource();
      await fixture.startAndWait(source, '#303030');

      await fixture.writeTheme('.dynamic/provider-next', '#505050');
      await Directory(fixture.themePath('.dynamic/provider')).rename(fixture.themePath('.dynamic/provider-old'));
      await Directory(fixture.themePath('.dynamic/provider-next')).rename(fixture.themePath('.dynamic/provider'));

      await fixture.waitForPalette(source, '#505050');
      expect(await Link(fixture.selectorPath).target(), '.dynamic/provider');

      await File(fixture.themePath('.dynamic/provider/Colors.qml')).writeAsString(_palette('#606060'));
      await fixture.waitForPalette(source, '#606060');
    });

    test('keeps the last valid palette through truncated content and recovers on a valid update', () async {
      await fixture.writeTheme('static-a', '#101010');
      await fixture.link('static-a', '.caelestia-use');
      final source = fixture.createSource();
      await fixture.startAndWait(source, '#101010');

      final paletteFile = File(fixture.themePath('.caelestia-use/Colors.qml'));
      await paletteFile.writeAsString('Singleton { property color background: "#202020"\n');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(source.palette?.colorScheme.surface, const Color(0xff101010));

      await paletteFile.writeAsString(_palette('#202020'));
      await fixture.waitForPalette(source, '#202020');
    });

    test('keeps the last valid palette through invalid UTF-8 and recovers on a valid update', () async {
      await fixture.writeTheme('static-a', '#101010');
      await fixture.link('static-a', '.caelestia-use');
      final source = fixture.createSource();
      await fixture.startAndWait(source, '#101010');

      final paletteFile = File(fixture.themePath('.caelestia-use/Colors.qml'));
      await paletteFile.writeAsBytes([0xff, 0xfe, 0x80]);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(source.palette?.colorScheme.surface, const Color(0xff101010));

      await paletteFile.writeAsString(_palette('#202020'));
      await fixture.waitForPalette(source, '#202020');
    });

    test('keeps the selected dynamic palette while its directory is unavailable, then recovers', () async {
      await fixture.writeTheme('.dynamic/noctalia', '#404040');
      await fixture.link('.dynamic/noctalia', '.caelestia-use');
      final source = fixture.createSource();
      await fixture.startAndWait(source, '#404040');

      await Directory(fixture.themePath('.dynamic/noctalia')).rename(fixture.themePath('.dynamic/noctalia-away'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(source.palette?.colorScheme.surface, const Color(0xff404040));

      await fixture.writeTheme('.dynamic/noctalia-restored', '#505050');
      await Directory(fixture.themePath('.dynamic/noctalia-restored')).rename(fixture.themePath('.dynamic/noctalia'));
      await fixture.waitForPalette(source, '#505050');
    });

    test('discovers a selector that appears after startup without a manual refresh', () async {
      await fixture.writeTheme('static-a', '#101010');
      await fixture.writeTheme('.dynamic/noctalia', '#404040');
      await fixture.link('static-a', 'current');
      final source = fixture.createSource();
      await fixture.startAndWait(source, '#101010');

      await fixture.link('.dynamic/noctalia', '.caelestia-use');

      await fixture.waitForPalette(source, '#404040');
    });

    test('watches an explicit palette path', () async {
      final override = File(path.join(fixture.root.path, 'custom', 'Colors.qml'));
      await override.parent.create(recursive: true);
      await override.writeAsString(_palette('#606060'));
      final source = fixture.createSource(palettePath: override.path);
      await fixture.startAndWait(source, '#606060');

      await override.writeAsString(_palette('#707070'));

      await fixture.waitForPalette(source, '#707070');
    });

    test('does not notify again when changed file content is identical', () async {
      await fixture.writeTheme('static-a', '#101010');
      await fixture.link('static-a', '.caelestia-use');
      final source = fixture.createSource();
      await fixture.startAndWait(source, '#101010');
      var notifications = 0;
      source.addListener(() => notifications++);
      final contents = await File(fixture.themePath('.caelestia-use/Colors.qml')).readAsString();

      await File(fixture.themePath('.caelestia-use/Colors.qml')).writeAsString(contents);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(notifications, 0);
    });

    test('periodic recovery reads a valid palette after an invalid startup file', () async {
      final themeDirectory = Directory(fixture.themePath('static-a'));
      await themeDirectory.create(recursive: true);
      final paletteFile = File(path.join(themeDirectory.path, 'Colors.qml'));
      await paletteFile.writeAsString('truncated');
      await fixture.link('static-a', '.caelestia-use');
      final source = fixture.createSource(
        debounce: const Duration(seconds: 5),
        recoveryInterval: const Duration(milliseconds: 80),
      );
      await source.refresh();
      expect(source.palette, isNull);

      await paletteFile.writeAsString(_palette('#808080'));

      await fixture.waitForPalette(source, '#808080');
    });

    test('does not load a palette when disabled', () async {
      await fixture.writeTheme('static-a', '#101010');
      await fixture.link('static-a', '.caelestia-use');
      final source = fixture.createSource(enabled: false);

      await source.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(source.palette, isNull);
    });

    test('stops notifying after disposal', () async {
      await fixture.writeTheme('static-a', '#101010');
      await fixture.link('static-a', '.caelestia-use');
      final source = fixture.createSource();
      await fixture.startAndWait(source, '#101010');
      var notifications = 0;
      source.addListener(() => notifications++);
      fixture.disposeSource(source);
      await File(fixture.themePath('.caelestia-use/Colors.qml')).writeAsString(_palette('#202020'));
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(notifications, 0);
    });
  }, skip: Platform.isWindows ? 'Directory symlink creation requires platform privileges on Windows.' : false);
}

class _ThemeFixture {
  _ThemeFixture(this.root) : themes = Directory(path.join(root.path, 'themes'));

  final Directory root;
  final Directory themes;
  final _sources = <DesktopThemeSource>[];

  String get selectorPath => path.join(themes.path, '.caelestia-use');

  static Future<_ThemeFixture> create() async {
    final root = await Directory.systemTemp.createTemp('desktop-theme-source-');
    final fixture = _ThemeFixture(root);
    await fixture.themes.create(recursive: true);
    return fixture;
  }

  String themePath(String relativePath) => path.join(themes.path, relativePath);

  Future<void> writeTheme(String relativePath, String background) async {
    final directory = Directory(themePath(relativePath));
    await directory.create(recursive: true);
    await File(path.join(directory.path, 'Colors.qml')).writeAsString(_palette(background));
  }

  Future<void> link(String target, String linkName) async {
    await Link(themePath(linkName)).create(target, recursive: true);
  }

  Future<void> replaceLink(String target, String linkName) async {
    final link = Link(themePath(linkName));
    final nextLink = Link('${link.path}.next');
    await nextLink.create(target, recursive: true);
    await nextLink.rename(link.path);
  }

  DesktopThemeSource createSource({
    String? palettePath,
    bool enabled = true,
    Duration debounce = const Duration(milliseconds: 20),
    Duration recoveryInterval = const Duration(seconds: 5),
  }) {
    final source = DesktopThemeSource(
      themesDirectory: themes.path,
      palettePath: palettePath,
      enabled: enabled,
      debounce: debounce,
      recoveryInterval: recoveryInterval,
    );
    _sources.add(source);
    return source;
  }

  void disposeSource(DesktopThemeSource source) {
    source.dispose();
    _sources.remove(source);
  }

  Future<void> startAndWait(DesktopThemeSource source, String background) async {
    await source.refresh();
    await waitForPalette(source, background);
  }

  Future<void> waitForPalette(DesktopThemeSource source, String background) async {
    const timeout = Duration(seconds: 4);
    const interval = Duration(milliseconds: 20);
    final expected = Color(int.parse(background.substring(1), radix: 16) | 0xff000000);
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (source.palette?.colorScheme.surface == expected) return;
      await Future<void>.delayed(interval);
    }
    fail('Expected surface $background within $timeout, got ${source.palette?.colorScheme.surface}.');
  }

  Future<void> dispose() async {
    for (final source in _sources) {
      source.dispose();
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await root.delete(recursive: true);
  }
}

String _palette(String background) =>
    '''
Singleton {
  property color background: "$background"
  property color backgroundAlt: "#282828"
  property color backgroundGray: "#383838"
  property color foreground: "#f0f0f0"
  property color foregroundInactive: "#b0b0b0"
  property color primary: "#70c0a0"
  property color muted: "#909090"
  property color border: "#606060"
  property color secondary: "#80a0e0"
  property color success: "#60c080"
  property color warning: "#e0b050"
  property color danger: "#e06060"
}
''';
