import 'package:flutter/material.dart';

/// 4px-derived spacing tokens for Gufi.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double xxxxl = 40.0;
  static const double huge = 48.0;
}

/// Border radii tokens for Gufi.
///
/// Source of Truth: Reference 1 (Radius & Elevation)
/// - XS ≈ 8px
/// - MD ≈ 16px
/// - LG ≈ 24px
/// - FULL = pill / circle
/// "Nothing in the product has a hard 90° corner."
class AppRadii {
  AppRadii._();

  static const double xs = 8.0;
  static const double sm = 8.0; // Alias to xs
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 28.0;
  static const double xxl = 32.0;
  static const double full = 999.0;

  static const BorderRadius xsBorder = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smBorder = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdBorder = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgBorder = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlBorder = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlBorder = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius fullBorder = BorderRadius.all(
    Radius.circular(full),
  );
}
