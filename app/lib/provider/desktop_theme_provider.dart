import 'package:localsend_app/util/native/desktop_theme_source.dart';
import 'package:localsend_app/util/ui/desktop_palette.dart';
import 'package:refena_flutter/refena_flutter.dart';

final desktopThemeProvider = NotifierProvider<DesktopThemeNotifier, DesktopPalette?>(
  (ref) => DesktopThemeNotifier(DesktopThemeSource.fromEnvironment()),
);

class DesktopThemeNotifier extends PureNotifier<DesktopPalette?> {
  final DesktopThemeSource _source;

  DesktopThemeNotifier(this._source);

  @override
  DesktopPalette? init() {
    _source.addListener(_onPaletteChanged);
    return _source.palette;
  }

  void _onPaletteChanged() {
    state = _source.palette;
  }

  @override
  void dispose() {
    _source.removeListener(_onPaletteChanged);
    _source.dispose();
    super.dispose();
  }
}
