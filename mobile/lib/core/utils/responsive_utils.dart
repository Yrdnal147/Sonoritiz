import 'package:flutter/material.dart';

class ResponsiveUtils {
  static const double mobileMaxSize = 600;
  static const double tabletMaxSize = 1100;

  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < mobileMaxSize;
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= mobileMaxSize && MediaQuery.of(context).size.width < tabletMaxSize;
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= tabletMaxSize;

  static int getGridCrossAxisCount(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width >= tabletMaxSize) return 5; // Desktop
    if (width >= mobileMaxSize) return 3; // Tablet
    return 2; // Mobile
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  const ResponsiveBuilder({
    Key? key,
    required this.mobile,
    this.tablet,
    this.desktop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveUtils.tabletMaxSize) {
          return desktop != null ? desktop!(context) : (tablet != null ? tablet!(context) : mobile(context));
        } else if (constraints.maxWidth >= ResponsiveUtils.mobileMaxSize) {
          return tablet != null ? tablet!(context) : mobile(context);
        } else {
          return mobile(context);
        }
      },
    );
  }
}
