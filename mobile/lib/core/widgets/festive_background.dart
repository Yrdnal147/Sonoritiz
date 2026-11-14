import 'package:flutter/material.dart';
import 'sonoritiz_dynamic_background.dart';

/// Rétrocompatibilité : redirige vers SonoritizDynamicBackground pour que
/// toutes les pages affichent uniformément la pochette floutée du morceau en cours.
class FestiveBackground extends StatelessWidget {
  final Widget child;

  const FestiveBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SonoritizDynamicBackground(
      child: child,
    );
  }
}
