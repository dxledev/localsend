import 'package:flutter/material.dart';

class SemanticColors extends ThemeExtension<SemanticColors> {
  final Color warning;
  final Color success;

  const SemanticColors({required this.warning, required this.success});

  @override
  SemanticColors copyWith({Color? warning, Color? success}) => SemanticColors(
    warning: warning ?? this.warning,
    success: success ?? this.success,
  );

  @override
  SemanticColors lerp(covariant SemanticColors? other, double t) {
    if (other == null) {
      return this;
    }
    return SemanticColors(
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}
