import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/provider/desktop_theme_provider.dart';
import 'package:localsend_app/util/native/desktop_theme_source.dart';
import 'package:localsend_app/util/ui/desktop_palette.dart';
import 'package:path/path.dart' as path;
import 'package:refena_flutter/refena_flutter.dart';

void main() {
  test('Refena adapter exposes the loaded palette, forwards updates, and stops on disposal', () async {
    final fixture = await _ProviderFixture.create();
    final source = DesktopThemeSource(
      themesDirectory: fixture.root.path,
      palettePath: fixture.paletteFile.path,
      debounce: const Duration(milliseconds: 20),
      recoveryInterval: const Duration(hours: 1),
    );
    final provider = NotifierProvider<DesktopThemeNotifier, DesktopPalette?>(
      (_) => DesktopThemeNotifier(source),
    );
    final container = RefenaContainer();
    DesktopThemeNotifier? notifier;

    try {
      await source.refresh();
      expect(source.palette?.colorScheme.surface, const Color(0xff121212));

      notifier = container.notifier(provider);
      expect(container.read(provider)?.colorScheme.surface, const Color(0xff121212));

      final nextState = container.stream(provider).first;
      await fixture.writePalette('#f8f7f3');
      final event = await nextState.timeout(const Duration(seconds: 2));

      expect(event.prev?.colorScheme.surface, const Color(0xff121212));
      expect(event.next?.colorScheme.surface, const Color(0xfff8f7f3));
      expect(container.read(provider)?.colorScheme.surface, const Color(0xfff8f7f3));

      final stateBeforeDispose = notifier.state;
      container.dispose(provider);
      expect(notifier.disposed, isTrue);

      await fixture.writePalette('#ffffff');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(source.palette?.colorScheme.surface, stateBeforeDispose?.colorScheme.surface);
      expect(notifier.state?.colorScheme.surface, stateBeforeDispose?.colorScheme.surface);
    } finally {
      if (notifier == null) {
        source.dispose();
      } else if (!notifier.disposed) {
        container.dispose(provider);
      }
      await fixture.dispose();
    }
  });
}

class _ProviderFixture {
  _ProviderFixture(this.root) : paletteFile = File(path.join(root.path, 'Colors.qml'));

  final Directory root;
  final File paletteFile;

  static Future<_ProviderFixture> create() async {
    final root = await Directory.systemTemp.createTemp('desktop-theme-provider-');
    final fixture = _ProviderFixture(root);
    await fixture.writePalette('#121212');
    return fixture;
  }

  Future<void> writePalette(String background) async {
    await paletteFile.writeAsString('''
Singleton {
  property color background: "$background"
  property color backgroundAlt: "#1c1c1c"
  property color backgroundGray: "#242424"
  property color foreground: "#f2f2f2"
  property color primary: "#43a084"
  property color secondary: "#58a8cf"
  property color success: "#4baf62"
  property color warning: "#f0af45"
  property color danger: "#ef6666"
}
''');
  }

  Future<void> dispose() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}
