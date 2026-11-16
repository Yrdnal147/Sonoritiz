import 'dart:ui' show DisplayFeature, DisplayFeatureType;
import 'package:flutter/material.dart';
import '../theme/app_breakpoints.dart';

enum SonoritizWindowClass {
  /// Écran très étroit (< 370dp, ex: écran externe Galaxy Z Fold).
  compactNarrow,

  /// Smartphone standard (370dp – 599dp).
  compact,

  /// Galaxy Z Fold déplié ou tablette portrait (600dp – 1023dp).
  medium,

  /// Tablette paysage, PC ou grand écran (>= 1024dp).
  expanded,
}

class ResponsiveUtils {
  static const double mobileMaxSize = AppBreakpoints.compact;
  static const double tabletMaxSize = AppBreakpoints.expanded;

  static SonoritizWindowClass windowClassOf(BuildContext context) {
    return windowClassFromWidth(MediaQuery.sizeOf(context).width);
  }

  static SonoritizWindowClass windowClassFromWidth(double width) {
    if (width < AppBreakpoints.compactNarrow) {
      return SonoritizWindowClass.compactNarrow;
    }
    if (width < AppBreakpoints.compact) {
      return SonoritizWindowClass.compact;
    }
    if (width < AppBreakpoints.expanded) {
      return SonoritizWindowClass.medium;
    }
    return SonoritizWindowClass.expanded;
  }

  static bool isCompactNarrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppBreakpoints.compactNarrow;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMaxSize;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileMaxSize && width < tabletMaxSize;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMaxSize;

  static bool isLargeScreen(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobileMaxSize;

  /// Détecte une charnière/pli vertical (ex: Galaxy Z Fold ouvert livre).
  static Rect? verticalHingeBounds(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    for (final DisplayFeature feature in MediaQuery.displayFeaturesOf(context)) {
      final isFoldOrHinge = feature.type == DisplayFeatureType.hinge ||
          feature.type == DisplayFeatureType.fold;
      if (!isFoldOrHinge) continue;
      final bounds = feature.bounds;
      if (bounds.height >= size.height * 0.65 && bounds.width < size.width * 0.25) {
        return bounds;
      }
    }
    return null;
  }

  /// Détecte une charnière/pli horizontal (ex: Galaxy Z Fold en mode Flex / Tabletop).
  static Rect? horizontalHingeBounds(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    for (final DisplayFeature feature in MediaQuery.displayFeaturesOf(context)) {
      final isFoldOrHinge = feature.type == DisplayFeatureType.hinge ||
          feature.type == DisplayFeatureType.fold;
      if (!isFoldOrHinge) continue;
      final bounds = feature.bounds;
      if (bounds.width >= size.width * 0.65 && bounds.height < size.height * 0.25) {
        return bounds;
      }
    }
    return null;
  }

  /// Indique si le lecteur plein écran doit passer en mode 2 volets côte-à-côte
  /// (Z Fold déplié, tablette, PC).
  static bool shouldUseSplitPlayer(BuildContext context) {
    if (verticalHingeBounds(context) != null) return true;
    final size = MediaQuery.sizeOf(context);
    return size.width >= 660 && size.width >= size.height * 0.72;
  }

  /// Calcule le nombre de colonnes optimal selon la largeur disponible.
  static int adaptiveGridColumns(
    double width, {
    int narrow = 2,
    int mobile = 2,
    int medium = 3,
    int expanded = 4,
    int ultraWide = 5,
  }) {
    if (width < 340) return narrow;
    if (width < AppBreakpoints.compact) return mobile;
    if (width < 900) return medium;
    if (width < AppBreakpoints.ultraWide) return expanded;
    return ultraWide;
  }

  static int getGridCrossAxisCount(BuildContext context) {
    return adaptiveGridColumns(
      MediaQuery.sizeOf(context).width,
      narrow: 2,
      mobile: 2,
      medium: 3,
      expanded: 4,
      ultraWide: 5,
    );
  }

  /// Marge horizontale adaptative selon le format d'écran.
  static double horizontalPagePadding(double width) {
    if (width < AppBreakpoints.compactNarrow) return 12.0;
    if (width < AppBreakpoints.compact) return 16.0;
    if (width < AppBreakpoints.expanded) return 22.0;
    return 28.0;
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveUtils.tabletMaxSize) {
          return desktop != null
              ? desktop!(context)
              : (tablet != null ? tablet!(context) : mobile(context));
        } else if (constraints.maxWidth >= ResponsiveUtils.mobileMaxSize) {
          return tablet != null ? tablet!(context) : mobile(context);
        } else {
          return mobile(context);
        }
      },
    );
  }
}

/// Centre et contraint la largeur maximale d'une vue (formulaires, paramètres,
/// pages éditoriales) sur tablette et PC tout en restant 100 % fluide sur mobile.
class ResponsiveContentConstraint extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContentConstraint({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.alignment = Alignment.topCenter,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    return Align(
      alignment: alignment,
      child: content,
    );
  }
}
