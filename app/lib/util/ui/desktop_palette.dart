import 'package:flutter/material.dart';

class DesktopPalette {
  const DesktopPalette._({
    required this.colorScheme,
    required this.warning,
    required this.success,
  });

  final ColorScheme colorScheme;
  final Color warning;
  final Color success;

  static DesktopPalette? parse(String qml) {
    final properties = _readColorProperties(qml);
    if (properties == null) return null;

    final resolved = <String, Color?>{};
    final background = _resolveColor('background', properties, resolved, {});
    final foreground = _resolveColor('foreground', properties, resolved, {});
    final primary = _resolveColor('primary', properties, resolved, {});
    if (background == null || foreground == null || primary == null) return null;

    final backgroundAlt = _optionalColor('backgroundAlt', background, properties, resolved);
    final backgroundGray = _optionalColor('backgroundGray', backgroundAlt, properties, resolved);
    final foregroundInactive = _optionalColor('foregroundInactive', foreground, properties, resolved);
    final muted = _optionalColor('muted', foregroundInactive, properties, resolved);
    final border = _optionalColor('border', backgroundGray, properties, resolved);
    final secondary = _optionalColor('secondary', primary, properties, resolved);
    final success = _optionalColor('success', primary, properties, resolved);
    final warning = _optionalColor('warning', secondary, properties, resolved);
    final danger = _optionalColor('danger', warning, properties, resolved);

    return _buildPalette(
      background: background,
      backgroundAlt: backgroundAlt,
      backgroundGray: backgroundGray,
      foreground: foreground,
      foregroundInactive: foregroundInactive,
      primary: primary,
      muted: muted,
      border: border,
      secondary: secondary,
      success: success,
      warning: warning,
      danger: danger,
    );
  }
}

DesktopPalette _buildPalette({
  required Color background,
  required Color backgroundAlt,
  required Color backgroundGray,
  required Color foreground,
  required Color foregroundInactive,
  required Color primary,
  required Color muted,
  required Color border,
  required Color secondary,
  required Color success,
  required Color warning,
  required Color danger,
}) {
  final brightness = ThemeData.estimateBrightnessForColor(background);
  final ramp = _surfaceRamp(background, backgroundAlt, backgroundGray, brightness);
  final surfaceBackgrounds = _uniqueColors([background, ...ramp]);
  final [containerLowest, containerLow, container, containerHigh, containerHighest] = ramp;
  final textCandidates = _uniqueColors([
    foreground,
    foregroundInactive,
    background,
    backgroundAlt,
    backgroundGray,
    muted,
    Colors.black,
    Colors.white,
  ]);
  final onSurface = _colorForContrast(foreground, surfaceBackgrounds, 4.5, textCandidates);
  final onSurfaceVariant = _colorForContrast(muted, surfaceBackgrounds, 4.5, textCandidates);
  final primaryText = _accentForContrast(primary, surfaceBackgrounds);
  final secondaryText = _accentForContrast(secondary, surfaceBackgrounds);
  final warningText = _accentForContrast(warning, surfaceBackgrounds);
  final successText = _accentForContrast(success, surfaceBackgrounds);
  final errorText = _accentForContrast(danger, surfaceBackgrounds);
  final outline = _colorForContrast(border, surfaceBackgrounds, 3, textCandidates);

  final primaryContainer = _blend(containerLow, primaryText, 0.18);
  final secondaryContainer = containerLow;
  final tertiaryContainer = _blend(container, warningText, 0.18);
  final errorContainer = _blend(container, errorText, 0.18);
  final inverseSurface = onSurface;
  final onInverseSurface = _colorForContrast(background, [inverseSurface], 4.5, textCandidates);
  final inversePrimary = _colorForContrast(primaryText, [inverseSurface], 4.5, textCandidates);
  final onPrimary = _colorForContrast(onSurface, [primaryText], 4.5, textCandidates);
  final onSecondary = _colorForContrast(onSurface, [secondaryText], 4.5, textCandidates);
  final onTertiary = _colorForContrast(onSurface, [warningText], 4.5, textCandidates);
  final onError = _colorForContrast(onSurface, [errorText], 4.5, textCandidates);

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: primaryText,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: _colorForContrast(primaryText, [primaryContainer], 4.5, textCandidates),
    primaryFixed: primaryText,
    primaryFixedDim: primaryText,
    onPrimaryFixed: onPrimary,
    onPrimaryFixedVariant: onPrimary,
    secondary: secondaryText,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSurface,
    secondaryFixed: secondaryText,
    secondaryFixedDim: secondaryText,
    onSecondaryFixed: onSecondary,
    onSecondaryFixedVariant: onSecondary,
    tertiary: warningText,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: _colorForContrast(warningText, [tertiaryContainer], 4.5, textCandidates),
    tertiaryFixed: warningText,
    tertiaryFixedDim: warningText,
    onTertiaryFixed: onTertiary,
    onTertiaryFixedVariant: onTertiary,
    error: errorText,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: _colorForContrast(errorText, [errorContainer], 4.5, textCandidates),
    surface: background,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: _colorForContrast(border, surfaceBackgrounds, 3, [outline, ...textCandidates]),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: inverseSurface,
    onInverseSurface: onInverseSurface,
    inversePrimary: inversePrimary,
    surfaceTint: Colors.transparent,
    surfaceDim: brightness == Brightness.dark ? ramp.first : ramp.last,
    surfaceBright: brightness == Brightness.dark ? ramp.last : ramp.first,
    surfaceContainerLowest: containerLowest,
    surfaceContainerLow: containerLow,
    surfaceContainer: container,
    surfaceContainerHigh: containerHigh,
    surfaceContainerHighest: containerHighest,
  );

  return DesktopPalette._(
    colorScheme: colorScheme,
    warning: warningText,
    success: successText,
  );
}

List<Color> _surfaceRamp(Color background, Color backgroundAlt, Color backgroundGray, Brightness brightness) {
  final colors = _uniqueColors([background, backgroundAlt, backgroundGray]);
  if (colors.length == 1) {
    final endpoint = brightness == Brightness.dark ? Colors.white : Colors.black;
    return List.generate(5, (index) => _blend(background, endpoint, index * 0.025));
  }

  colors.sort((first, second) {
    final luminanceOrder = first.computeLuminance().compareTo(second.computeLuminance());
    return brightness == Brightness.dark ? luminanceOrder : -luminanceOrder;
  });

  return List.generate(5, (index) {
    final position = index / 4 * (colors.length - 1);
    final startIndex = position.floor();
    final endIndex = position.ceil();
    final amount = position - startIndex;
    return _blend(colors[startIndex], colors[endIndex], amount);
  });
}

Color _colorForContrast(Color preferred, List<Color> backgrounds, double ratio, List<Color> candidates) {
  if (_hasContrast(preferred, backgrounds, ratio)) return preferred;
  for (final candidate in candidates) {
    if (_hasContrast(candidate, backgrounds, ratio)) return candidate;
  }
  return _adjustForContrast(preferred, backgrounds, ratio);
}

Color _accentForContrast(Color preferred, List<Color> backgrounds) {
  return _hasContrast(preferred, backgrounds, 4.5) ? preferred : _adjustForContrast(preferred, backgrounds, 4.5);
}

Color _adjustForContrast(Color source, List<Color> backgrounds, double ratio) {
  Color? best;
  var bestAmount = double.infinity;
  for (final endpoint in [Colors.black, Colors.white]) {
    if (!_hasContrast(endpoint, backgrounds, ratio)) continue;
    var low = 0.0;
    var high = 1.0;
    for (var iteration = 0; iteration < 24; iteration++) {
      final amount = (low + high) / 2;
      if (_hasContrast(_blend(source, endpoint, amount), backgrounds, ratio)) {
        high = amount;
      } else {
        low = amount;
      }
    }
    if (high < bestAmount) {
      bestAmount = high;
      best = _blend(source, endpoint, high);
    }
  }

  if (best != null) return best;
  return _uniqueColors([Colors.black, Colors.white]).reduce((first, second) {
    final firstMinimum = _minimumContrast(first, backgrounds);
    final secondMinimum = _minimumContrast(second, backgrounds);
    return firstMinimum >= secondMinimum ? first : second;
  });
}

bool _hasContrast(Color foreground, List<Color> backgrounds, double minimum) {
  return backgrounds.every((background) => _contrastRatio(foreground, background) >= minimum);
}

double _minimumContrast(Color foreground, List<Color> backgrounds) {
  return backgrounds.map((background) => _contrastRatio(foreground, background)).reduce((a, b) => a < b ? a : b);
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker = firstLuminance < secondLuminance ? firstLuminance : secondLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

Color _blend(Color first, Color second, double amount) {
  return Color.lerp(first, second, amount)!.withValues(alpha: 1);
}

List<Color> _uniqueColors(List<Color> colors) {
  final result = <Color>[];
  for (final color in colors) {
    if (!result.contains(color)) result.add(color);
  }
  return result;
}

Map<String, String>? _readColorProperties(String qml) {
  final source = qml.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ').replaceAll(RegExp(r'//[^\r\n]*'), '');
  var depth = 0;
  var opened = false;
  for (final character in source.codeUnits) {
    if (character == 123) {
      depth++;
      opened = true;
    } else if (character == 125) {
      depth--;
      if (depth < 0) return null;
    }
  }
  if (!opened || depth != 0) return null;

  final properties = <String, String>{};
  final declaration = RegExp(
    r'^[ \t]*(?:readonly[ \t]+)?property[ \t]+color[ \t]+([A-Za-z_]\w*)[ \t]*:[ \t]*(.*?)[ \t]*;?[ \t]*$',
    multiLine: true,
  );
  for (final match in declaration.allMatches(source)) {
    final name = match.group(1)!;
    if (properties.containsKey(name)) return null;
    properties[name] = match.group(2)!.trim();
  }
  return properties.isEmpty ? null : properties;
}

Color _optionalColor(String name, Color fallback, Map<String, String> properties, Map<String, Color?> resolved) {
  return _resolveColor(name, properties, resolved, {}) ?? fallback;
}

Color? _resolveColor(String name, Map<String, String> properties, Map<String, Color?> resolved, Set<String> resolving) {
  if (resolved.containsKey(name)) return resolved[name];
  if (!resolving.add(name)) return null;
  final expression = properties[name];
  if (expression == null) return null;

  final color = _parseColor(expression) ?? _parseAlias(expression, properties, resolved, resolving);
  resolved[name] = color;
  resolving.remove(name);
  return color;
}

Color? _parseAlias(String expression, Map<String, String> properties, Map<String, Color?> resolved, Set<String> resolving) {
  final alias = RegExp(r'^(?:[A-Za-z_]\w*\.)*([A-Za-z_]\w*)$').firstMatch(expression)?.group(1);
  if (alias == null) return null;
  return _resolveColor(alias, properties, resolved, resolving);
}

Color? _parseColor(String expression) {
  if (expression.length >= 2 &&
      ((expression.startsWith('"') && expression.endsWith('"')) || (expression.startsWith("'") && expression.endsWith("'")))) {
    expression = expression.substring(1, expression.length - 1);
  }
  final hex = RegExp(r'^#([\da-fA-F]{3}|[\da-fA-F]{6}|[\da-fA-F]{8})$').firstMatch(expression)?.group(1);
  if (hex != null) {
    if (hex.length == 3) {
      final red = int.parse('${hex[0]}${hex[0]}', radix: 16);
      final green = int.parse('${hex[1]}${hex[1]}', radix: 16);
      final blue = int.parse('${hex[2]}${hex[2]}', radix: 16);
      return Color.fromARGB(255, red, green, blue);
    }
    final offset = hex.length == 8 ? 2 : 0; // Qt puts alpha before the RGB channels in eight-digit literals.
    final red = int.parse(hex.substring(offset, offset + 2), radix: 16);
    final green = int.parse(hex.substring(offset + 2, offset + 4), radix: 16);
    final blue = int.parse(hex.substring(offset + 4, offset + 6), radix: 16);
    return Color.fromARGB(255, red, green, blue);
  }

  final rgba = RegExp(r'^Qt\.rgba\s*\((.*)\)$').firstMatch(expression)?.group(1);
  if (rgba == null) return null;
  final components = rgba.split(',');
  if (components.length != 4) return null;
  final values = components.map(_parseUnitInterval).toList();
  if (values.any((value) => value == null)) return null;
  return Color.fromARGB(
    255,
    _toColorChannel(values[0]!),
    _toColorChannel(values[1]!),
    _toColorChannel(values[2]!),
  );
}

double? _parseUnitInterval(String expression) {
  final number = r'[+-]?(?:\d+(?:\.\d*)?|\.\d+)';
  final match = RegExp('^($number)(?:\\s*/\\s*($number))?\$').firstMatch(expression.trim());
  if (match == null) return null;
  final numerator = double.tryParse(match.group(1)!);
  final denominator = double.tryParse(match.group(2) ?? '1');
  if (numerator == null || denominator == null || denominator == 0) return null;
  final value = numerator / denominator;
  return value >= 0 && value <= 1 ? value : null;
}

int _toColorChannel(double value) => (value * 255).round().clamp(0, 255).toInt();
