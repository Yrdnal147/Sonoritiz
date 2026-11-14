import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../onboarding/presentation/widgets/artist_picker_view.dart';
import '../cubit/home_cubit.dart';

class SelectArtistsScreen extends StatelessWidget {
  const SelectArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    return SonoritizArtistPickerView(
      title: 'Vos artistes préférés',
      subtitle:
          'Ajustez vos artistes favoris pour affiner instantanément vos mix et recommandations personnelles.',
      initialSelected: storage.getFavoriteArtists(),
      minRequired: 1,
      maxAllowed: 25,
      onBack: () => context.pop(),
      submitLabelBuilder: (count, canProceed) =>
          canProceed ? 'Enregistrer ($count)' : 'Choisissez au moins 1 artiste',
      onSubmit: (selected) async {
        await storage.setOnboardingSeenFor(storage.accountScope, true);
        if (context.mounted) {
          try {
            await context.read<HomeCubit>().saveFavoriteArtists(selected);
          } catch (_) {
            await storage.saveFavoriteArtists(selected);
          }
          if (context.mounted) {
            context.pop();
          }
        }
      },
    );
  }
}
