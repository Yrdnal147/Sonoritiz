import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/storage/storage_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _username = '';
  String _email = '';
  bool _loaded = false;
  String? _profileImagePath;
  int _localFilesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final storage = StorageService();
    await storage.init();
    setState(() {
      _username = storage.username;
      _email = storage.email;
      _profileImagePath = storage.getProfileImagePath();
      _localFilesCount = storage.getLocalFiles().length;
      _loaded = true;
    });
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final dir = await getApplicationDocumentsDirectory();
        final File newImage = File('${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await File(pickedFile.path).copy(newImage.path);
        
        final storage = StorageService();
        await storage.init();
        await storage.saveProfileImagePath(newImage.path);
        
        setState(() {
          _profileImagePath = newImage.path;
        });
      }
    } catch (e) {
      debugPrint("Erreur lors de la sélection de l'image : $e");
    }
  }

  void _logout() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Se déconnecter", style: TextStyle(color: Colors.white)),
        content: const Text("Es-tu sûr de vouloir te déconnecter ?", style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Annuler", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final storage = StorageService();
              await storage.init();
              await storage.clearSession();
              if (mounted) {
                context.read<PlayerCubit>().pause();
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text("Déconnexion"),
          ),
        ],
      ),
    );
  }

  void _showCcLicenseInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text("Licence Creative Commons", style: TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Sonoritiz utilise l'API de Jamendo. Les morceaux disponibles sur cette plateforme sont distribués sous licences Creative Commons, permettant aux artistes indépendants de partager leur musique librement tout en conservant certains droits.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer", style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                // En-tête personnalisé (SliverAppBar)
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: AppColors.background,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Bannière de fond floue avec dégradé
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withOpacity(0.4),
                                AppColors.background,
                              ],
                            ),
                          ),
                        ),
                        // Avatar et Infos
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: _pickProfileImage,
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.primary, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.3),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          )
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 56,
                                        backgroundColor: AppColors.surface,
                                        backgroundImage: _profileImagePath != null && File(_profileImagePath!).existsSync()
                                            ? FileImage(File(_profileImagePath!))
                                            : null,
                                        child: _profileImagePath == null || !File(_profileImagePath!).existsSync()
                                            ? Text(
                                                _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                                                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primary),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ],
                                ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _username.isNotEmpty ? _username : 'Utilisateur',
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                              ).animate().fadeIn(delay: 400.ms),
                              const SizedBox(height: 4),
                              Text(
                                _email.isNotEmpty ? _email : 'email@example.com',
                                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                              ).animate().fadeIn(delay: 500.ms),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Corps du profil
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      children: [
                        // Statistiques
                        Row(
                          children: [
                            _buildStatCard("Sons locaux", _localFilesCount.toString(), Icons.folder_open_sharp),
                            const SizedBox(width: 16),
                            _buildStatCard("Favoris", "-", Icons.favorite),
                          ],
                        ).animate().slideY(begin: 0.2, delay: 600.ms).fadeIn(),

                        const SizedBox(height: 32),

                        // Section Paramètres
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Paramètres", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _buildSettingsTile(Icons.music_note, "Qualité audio", "Haute", isSwitch: false),
                              const Divider(color: Colors.white12, height: 1),
                              _buildSettingsTile(Icons.notifications_outlined, "Notifications push", "Activées", isSwitch: true),
                              const Divider(color: Colors.white12, height: 1),
                              _buildSettingsTile(Icons.dark_mode_outlined, "Mode Sombre", "Toujours actif", isSwitch: true, initialSwitchValue: true),
                            ],
                          ),
                        ).animate().fadeIn(delay: 700.ms),

                        const SizedBox(height: 32),
                        
                        // Section A propos
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("À propos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _buildSettingsTile(Icons.info_outline, "Version", "1.0.0", isSwitch: false, hasArrow: false),
                              const Divider(color: Colors.white12, height: 1),
                              _buildSettingsTile(Icons.description_outlined, "Licences CC", "Jamendo", onTap: () => _showCcLicenseInfo(context)),
                            ],
                          ),
                        ).animate().fadeIn(delay: 800.ms),

                        const SizedBox(height: 40),

                        // Logout button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout, color: AppColors.error),
                            label: const Text("Se déconnecter", style: TextStyle(color: AppColors.error, fontSize: 16, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ).animate().fadeIn(delay: 900.ms),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, {VoidCallback? onTap, bool isSwitch = false, bool initialSwitchValue = false, bool hasArrow = true}) {
    return ListTile(
      onTap: isSwitch ? null : onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: isSwitch 
          ? Switch(
              value: initialSwitchValue,
              onChanged: (val) {},
              activeColor: AppColors.primary,
            )
          : hasArrow ? const Icon(Icons.chevron_right, color: AppColors.textSecondary) : null,
    );
  }
}
