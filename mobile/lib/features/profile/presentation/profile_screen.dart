import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/storage/storage_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'stats_screen.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: const Text("Se déconnecter"),
        content: const Text("Es-tu sûr de vouloir te déconnecter ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Annuler", style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
            style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError),
            child: const Text("Déconnexion"),
          ),
        ],
      ),
    );
  }

  void _showCcLicenseInfo(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: colorScheme.primary),
            const SizedBox(width: AppDimensions.spacingSm),
            const Expanded(child: Text("Licence Creative Commons")),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Sonoritiz utilise l'API de Jamendo. Les morceaux disponibles sur cette plateforme sont distribués sous licences Creative Commons, permettant aux artistes indépendants de partager leur musique librement tout en conservant certains droits.",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: colorScheme.surface,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorScheme.primaryContainer,
                                colorScheme.surface,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: AppDimensions.spacingLg,
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
                                        border: Border.all(color: colorScheme.primary, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colorScheme.primary.withOpacity(0.3),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          )
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 56,
                                        backgroundColor: colorScheme.surfaceContainerHighest,
                                        backgroundImage: _profileImagePath != null && File(_profileImagePath!).existsSync()
                                            ? FileImage(File(_profileImagePath!))
                                            : null,
                                        child: _profileImagePath == null || !File(_profileImagePath!).existsSync()
                                            ? Text(
                                                _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                                                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: colorScheme.primary),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(AppDimensions.spacingSm),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.camera_alt_rounded, color: colorScheme.onPrimary, size: AppDimensions.iconSm),
                                      ),
                                    ),
                                  ],
                                ).animate().scale(delay: AppAnimations.normal, duration: AppAnimations.slow, curve: Curves.easeOutBack),
                              ),
                              const SizedBox(height: AppDimensions.spacingMd),
                              Text(
                                _username.isNotEmpty ? _username : 'Utilisateur',
                                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              ).animate().fadeIn(delay: 400.ms),
                              const SizedBox(height: 4),
                              Text(
                                _email.isNotEmpty ? _email : 'email@example.com',
                                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                              ).animate().fadeIn(delay: 500.ms),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingLg, vertical: AppDimensions.spacingXl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
                          },
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                              gradient: LinearGradient(
                                colors: [colorScheme.primary, colorScheme.tertiary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -20,
                                  bottom: -20,
                                  child: Icon(Icons.bar_chart_rounded, size: 100, color: colorScheme.onPrimary.withOpacity(0.2)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(AppDimensions.spacingLg),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(AppDimensions.spacingSm),
                                        decoration: BoxDecoration(
                                          color: colorScheme.onPrimary.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.analytics_outlined, color: colorScheme.onPrimary, size: 28),
                                      ),
                                      const SizedBox(width: AppDimensions.spacingMd),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              "Vos Statistiques",
                                              style: textTheme.titleMedium?.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Découvrez votre Replay musical",
                                              style: textTheme.bodySmall?.copyWith(color: colorScheme.onPrimary.withOpacity(0.8)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.arrow_forward_ios_rounded, color: colorScheme.onPrimary, size: AppDimensions.iconSm),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),
                        ),
                        const SizedBox(height: AppDimensions.spacingXxl),

                        Text("PARAMÈTRES", style: textTheme.labelMedium?.copyWith(letterSpacing: 1.5, color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: AppDimensions.spacingMd),
                        Row(
                          children: [
                            _buildStatCard(context, "Sons locaux", _localFilesCount.toString(), Icons.folder_open_sharp),
                            const SizedBox(width: AppDimensions.spacingMd),
                            _buildStatCard(context, "Favoris", "-", Icons.favorite_rounded),
                          ],
                        ).animate().slideY(begin: 0.2, delay: 600.ms).fadeIn(),

                        const SizedBox(height: AppDimensions.spacingXxl),

                        Text("Paramètres", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppDimensions.spacingMd),
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                          ),
                          child: Column(
                            children: [
                              _buildSettingsTile(context, Icons.music_note_rounded, "Qualité audio", "Haute", isSwitch: false),
                              Divider(color: colorScheme.outline.withOpacity(0.2), height: 1),
                              _buildSettingsTile(context, Icons.notifications_outlined, "Notifications push", "Activées", isSwitch: true),
                              Divider(color: colorScheme.outline.withOpacity(0.2), height: 1),
                              _buildSettingsTile(context, Icons.dark_mode_outlined, "Mode Sombre", "Toujours actif", isSwitch: true, initialSwitchValue: true),
                            ],
                          ),
                        ).animate().fadeIn(delay: 700.ms),

                        const SizedBox(height: AppDimensions.spacingXxl),
                        
                        Text("À propos", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppDimensions.spacingMd),
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                          ),
                          child: Column(
                            children: [
                              _buildSettingsTile(context, Icons.info_outline_rounded, "Version", "1.0.0", isSwitch: false, hasArrow: false),
                              Divider(color: colorScheme.outline.withOpacity(0.2), height: 1),
                              _buildSettingsTile(context, Icons.description_outlined, "Licences CC", "Jamendo", onTap: () => _showCcLicenseInfo(context)),
                            ],
                          ),
                        ).animate().fadeIn(delay: 800.ms),

                        const SizedBox(height: AppDimensions.spacingXxl * 1.5),

                        SizedBox(
                          width: double.infinity,
                          height: AppDimensions.buttonHeight,
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            icon: Icon(Icons.logout_rounded, color: colorScheme.error),
                            label: Text("Se déconnecter", style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: colorScheme.error, width: 1.5),
                            ),
                          ),
                        ).animate().fadeIn(delay: 900.ms),
                        
                        const SizedBox(height: AppDimensions.spacingXxl * 2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingLg),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: Column(
          children: [
            Icon(icon, color: colorScheme.primary, size: 28),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(value, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, IconData icon, String title, String subtitle, {VoidCallback? onTap, bool isSwitch = false, bool initialSwitchValue = false, bool hasArrow = true}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      onTap: isSwitch ? null : onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd, vertical: AppDimensions.spacingXs),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Icon(icon, color: colorScheme.primary, size: 22),
      ),
      title: Text(title, style: textTheme.titleSmall),
      subtitle: Text(subtitle, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
      trailing: isSwitch 
          ? Switch(
              value: initialSwitchValue,
              onChanged: (val) {},
              activeColor: colorScheme.primary,
            )
          : hasArrow ? Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant) : null,
    );
  }
}
