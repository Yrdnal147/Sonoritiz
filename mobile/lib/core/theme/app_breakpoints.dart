class AppBreakpoints {
  /// Écran externe étroit type Galaxy Z Fold replié (~320–368dp).
  static const double compactNarrow = 370.0;

  /// Seuil historique petit mobile.
  static const double mobileSmall = 360.0;

  /// Mobile standard.
  static const double mobile = 400.0;

  /// Seuil fin de mobile / début Z Fold déplié & tablette portrait (600dp).
  static const double compact = 600.0;
  static const double tablet = 600.0;

  /// Seuil tablette confortable / grand pliable déplié.
  static const double medium = 840.0;

  /// Seuil desktop / tablette paysage / PC (>= 1024dp).
  static const double expanded = 1024.0;
  static const double desktop = 1024.0;

  /// Seuil écran large PC (>= 1280dp).
  static const double ultraWide = 1280.0;

  /// Largeurs maximales recommandées pour la lisibilité UI/UX.
  static const double maxFormWidth = 480.0;
  static const double maxSettingsWidth = 760.0;
  static const double maxContentWidth = 1380.0;
}
