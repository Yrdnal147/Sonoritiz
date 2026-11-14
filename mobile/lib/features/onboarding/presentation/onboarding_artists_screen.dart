import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/storage/storage_service.dart';
import '../../home/presentation/cubit/home_cubit.dart';
import 'widgets/artist_picker_view.dart';

class OnboardingArtistScreen extends StatelessWidget {
  static const int minArtistsRequired = 3;

  const OnboardingArtistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    return SonoritizArtistPickerView(
      title: 'Choisissez vos artistes',
      subtitle:
          'Sélectionnez au moins 3 artistes (ou explorez par univers musical) pour façonner un accueil 100 % adapté à vos goûts.',
      initialSelected: storage.getFavoriteArtists(),
      minRequired: minArtistsRequired,
      maxAllowed: 25,
      submitLabelBuilder: (count, canProceed) {
        if (canProceed) {
          return 'Commencer mon écoute ($count)';
        }
        final remaining = minArtistsRequired - count;
        return 'Encore $remaining artiste${remaining > 1 ? 's' : ''} minimum ($count/$minArtistsRequired)';
      },
      onSubmit: (selected) async {
        await storage.setOnboardingSeenFor(storage.accountScope, true);
        await storage.saveFavoriteArtists(selected);
        await storage.clearWeeklyPlaylistsCache();
        if (context.mounted) {
          try {
            unawaited(
              context.read<HomeCubit>().loadHomeData(forceRefresh: true),
            );
          } catch (_) {}
          context.go('/home');
        }
      },
    );
  }
}
