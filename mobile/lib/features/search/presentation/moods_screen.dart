import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import 'widgets/sonoritiz_moods_widget.dart';

/// Page dédiée Sonoritiz Moods accessible depuis Recherche ou raccourci direct.
class MoodsScreen extends StatelessWidget {
  const MoodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/search');
            }
          },
        ),
        title: const Text(
          'Sonoritiz Moods',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.only(top: 8, bottom: 130),
        child: SonoritizMoodsWidget(
          showFullScreenButton: false,
          stageHeight: 360,
        ),
      ),
    );
  }
}
