import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_service.dart';
import 'cubit/connect_cubit.dart';
import 'cubit/connect_state.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConnectCubit>(
      create: (context) => ConnectCubit(
        apiClient: ApiClient(storageService: StorageService()),
        storageService: StorageService()..init(),
      ),
      child: const _ConnectScreenBody(),
    );
  }
}

class _ConnectScreenBody extends StatelessWidget {
  const _ConnectScreenBody({Key? key}) : super(key: key);

  void _showJoinDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Rejoindre une session", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(hintText: "Code à 6 caractères (ex: X8K2P9)"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Annuler", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<ConnectCubit>().joinSession(controller.text.trim());
                Navigator.pop(dialogContext);
              }
            },
            child: const Text("Rejoindre"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text("Connect", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: BlocBuilder<ConnectCubit, ConnectState>(
        builder: (context, state) {
          if (state is ConnectLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (state is ConnectActive) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  const Text("Code d'invitation", style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  const SizedBox(height: 12),
                  // Large invite code card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Text(
                          state.inviteCode,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: state.inviteCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Code d'invitation copié !")),
                            );
                          },
                          icon: const Icon(Icons.copy, color: AppColors.primary, size: 18),
                          label: const Text("Copier le code", style: TextStyle(color: AppColors.primary)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text("Participants connectés", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Horizontal connected participants avatars with status dots
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.participants.length,
                      itemBuilder: (context, index) {
                        final p = state.participants[index];
                        return Container(
                          margin: const EdgeInsets.only(right: 16),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: AppColors.surfaceLight,
                                    child: Text(
                                      (p['username'] ?? 'P')[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.background, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p['username'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 32),
                  // Quit session red button
                  ElevatedButton(
                    onPressed: () => context.read<ConnectCubit>().leaveSession(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("Quitter la session"),
                  ),
                ],
              ),
             ),
            );
          }

          // Default entry screen
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                const Icon(Icons.sensors, size: 80, color: AppColors.primary),
                const SizedBox(height: 24),
                const Text(
                  "Écoute synchronisée",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Écoutez de la musique simultanément entre deux appareils en temps réel.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 48),

                // Button 1: Créer une session (solid orange)
                ElevatedButton(
                  onPressed: () => context.read<ConnectCubit>().createSession(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text("Créer une session"),
                ),
                const SizedBox(height: 16),

                // Button 2: Rejoindre avec un code (orange outline)
                OutlinedButton(
                  onPressed: () => _showJoinDialog(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Rejoindre avec un code", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
           ),
          );
        },
      ),
    );
  }
}
