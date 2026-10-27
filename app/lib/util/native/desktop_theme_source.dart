import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:localsend_app/util/ui/desktop_palette.dart';
import 'package:path/path.dart' as path;

class DesktopThemeSource extends ChangeNotifier {
  final String themesDirectory;
  final String? palettePath;
  final bool enabled;
  final Duration debounce;
  final Duration recoveryInterval;

  final _subscriptions = <String, StreamSubscription<FileSystemEvent>>{};
  Timer? _debounceTimer;
  Timer? _recoveryTimer;
  Future<void>? _refreshTask;
  bool _refreshRequested = false;
  bool _rearmWatches = false;
  bool _disposed = false;
  String? _lastPath;
  String? _lastContents;
  DesktopPalette? _palette;

  DesktopThemeSource({
    required this.themesDirectory,
    this.palettePath,
    this.enabled = true,
    this.debounce = const Duration(milliseconds: 120),
    this.recoveryInterval = const Duration(seconds: 5),
  }) {
    if (enabled) {
      unawaited(refresh());
      _recoveryTimer = Timer.periodic(recoveryInterval, (_) {
        _rearmWatches = true;
        unawaited(refresh());
      });
    }
  }

  factory DesktopThemeSource.fromEnvironment() {
    final environment = Platform.environment;
    final home = environment['HOME'];
    final configHome = environment['XDG_CONFIG_HOME'];
    final configDirectory = configHome != null && path.isAbsolute(configHome) ? configHome : path.join(home ?? '', '.config');
    final override = environment['LOCALSEND_DESKTOP_PALETTE'];
    return DesktopThemeSource(
      themesDirectory: path.join(configDirectory, 'themes'),
      palettePath: override == null || override.isEmpty ? null : override,
      enabled: Platform.isLinux && (home != null || path.isAbsolute(configDirectory)),
    );
  }

  DesktopPalette? get palette => _palette;

  Future<void> refresh() {
    if (!enabled || _disposed) {
      return Future.value();
    }
    _refreshRequested = true;
    return _refreshTask ??= _drainRefreshes();
  }

  Future<void> _drainRefreshes() async {
    try {
      while (_refreshRequested && !_disposed) {
        _refreshRequested = false;
        await _readPalette();
        if (!_disposed) {
          await _updateWatches();
        }
      }
    } finally {
      _refreshTask = null;
    }
  }

  Future<String> _selectedPath() async {
    if (palettePath != null) {
      return palettePath!;
    }
    final selector = path.join(themesDirectory, '.caelestia-use');
    final selected = path.join(selector, 'Colors.qml');
    final selectorExists = await FileSystemEntity.type(selector, followLinks: false) != FileSystemEntityType.notFound;
    // Keep the last palette during the renderer's brief directory replacement gap.
    return selectorExists || _lastPath == selected ? selected : path.join(themesDirectory, 'current', 'Colors.qml');
  }

  Future<void> _readPalette() async {
    try {
      final selected = await _selectedPath();
      final contents = await File(selected).readAsString();
      if (_disposed || (selected == _lastPath && contents == _lastContents)) {
        return;
      }
      final next = DesktopPalette.parse(contents);
      if (next == null) {
        return;
      }
      _lastPath = selected;
      _lastContents = contents;
      if (_palette?.colorScheme == next.colorScheme && _palette?.warning == next.warning && _palette?.success == next.success) {
        return;
      }
      _palette = next;
      notifyListeners();
    } on FileSystemException {
      // A missing or incomplete live update must not replace a working palette.
    } on FormatException {
      // Partially written UTF-8 is retried with the next filesystem notification.
    }
  }

  Future<Set<String>> _watchDirectories() async {
    final files = palettePath != null
        ? [palettePath!]
        : [path.join(themesDirectory, '.caelestia-use', 'Colors.qml'), path.join(themesDirectory, 'current', 'Colors.qml')];
    final candidates = <String>{
      if (palettePath == null) ...[themesDirectory, path.dirname(themesDirectory), path.join(themesDirectory, '.dynamic')],
    };
    for (final filePath in files) {
      candidates.add(path.dirname(filePath));
      candidates.add(path.dirname(path.dirname(filePath)));
      try {
        final target = await File(filePath).resolveSymbolicLinks();
        candidates.add(path.dirname(target));
        candidates.add(path.dirname(path.dirname(target)));
      } on FileSystemException {
        // Parent watches discover selectors and targets created after startup.
      }
    }
    final directories = <String>{};
    for (var candidate in candidates) {
      try {
        while (!await Directory(candidate).exists()) {
          final parent = path.dirname(candidate);
          if (candidate == parent) {
            break;
          }
          candidate = parent;
        }
        directories.add(await Directory(candidate).resolveSymbolicLinks());
      } on FileSystemException {
        // Periodic recovery re-arms watches after inaccessible directories return.
      }
    }
    return directories;
  }

  Future<void> _updateWatches() async {
    final directories = await _watchDirectories();
    if (_disposed) {
      return;
    }
    final rearm = _rearmWatches;
    _rearmWatches = false;
    // The renderer can replace a directory's inode without changing its pathname.
    for (final obsolete in _subscriptions.keys.where((directory) => rearm || !directories.contains(directory)).toList()) {
      await _subscriptions.remove(obsolete)?.cancel();
    }
    for (final directory in directories) {
      if (_disposed || _subscriptions.containsKey(directory)) {
        continue;
      }
      try {
        _subscriptions[directory] = Directory(directory).watch().listen(
          (_) => _scheduleRefresh(),
          onError: (Object error) => _watchEnded(directory),
          onDone: () => _watchEnded(directory),
          cancelOnError: true,
        );
      } on FileSystemException {
        // Filesystem notifications are optional; recovery also refreshes the palette.
      }
    }
  }

  void _watchEnded(String directory) {
    _subscriptions.remove(directory);
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    if (_disposed) {
      return;
    }
    _debounceTimer?.cancel();
    _rearmWatches = true;
    _debounceTimer = Timer(debounce, () => unawaited(refresh()));
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _recoveryTimer?.cancel();
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    super.dispose();
  }
}
