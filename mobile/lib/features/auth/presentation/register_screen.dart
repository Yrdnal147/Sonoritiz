import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/session_coordinator.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sonoritiz_brand_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _extractAuthError(
    Object e, {
    String fallback = "Erreur lors de l'inscription.",
  }) =>
      ApiClient.formatAuthError(e, fallback: fallback);

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorMessage = 'Veuillez remplir tous les champs.');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Les mots de passe ne correspondent pas.');
      return;
    }

    if (password.length < 8) {
      setState(() => _errorMessage = 'Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storageService = StorageService();
      final apiClient = ApiClient(storageService: storageService);

      final response = await apiClient.post(ApiConstants.register, data: {
        'username': username,
        'email': email,
        'password': password,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data is Map ? response.data as Map : const {};
        if (data['tokens'] is Map) {
          final tokens = data['tokens'] as Map;
          await storageService.saveTokens(
            accessToken: (tokens['access'] ?? '').toString(),
            refreshToken: (tokens['refresh'] ?? '').toString(),
          );
          final user = (data['user'] is Map) ? data['user'] as Map : const {};
          if (!mounted) return;
          final nextRoute = await SessionCoordinator.handleAuthenticatedUser(
            context,
            username: (user['username'] ?? username).toString(),
            email: (user['email'] ?? email).toString(),
            isNewAccount: true,
            serverFavoriteArtists: const [],
            serverSuperlikes: const [],
            serverFavoriteAlbums: const [],
          );
          if (mounted) {
            context.go(nextRoute);
          }
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Compte créé avec succès ! Connectez-vous pour personnaliser votre espace.',
              ),
              backgroundColor: AppColors.primary,
            ),
          );
          context.go('/login');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = _extractAuthError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId:
            '332358147050-fj2huukn8hcf40dukiuta1hc393lmh5a.apps.googleusercontent.com',
      );
      try {
        await googleSignIn.signOut();
      } catch (_) {}
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        setState(() {
          _errorMessage = "Impossible d'obtenir le jeton Google.";
          _isGoogleLoading = false;
        });
        return;
      }

      final storageService = StorageService();
      final apiClient = ApiClient(storageService: storageService);
      final response = await apiClient.post(ApiConstants.googleLogin, data: {
        'id_token': idToken,
      });

      if (response.statusCode == 200) {
        final data = response.data is Map ? response.data as Map : const {};
        final bool isNewUser = data['is_new_user'] == true;
        final user = (data['user'] is Map) ? data['user'] as Map : const {};
        final userEmail = (user['email'] ?? googleUser.email).toString();
        final tokens = (data['tokens'] is Map) ? data['tokens'] as Map : const {};
        final serverArtists = user['favorite_artists'] is List
            ? user['favorite_artists'] as List
            : null;
        final serverSuperlikes = user['superliked_tracks'] is List
            ? user['superliked_tracks'] as List
            : null;
        final serverFavoriteAlbums = user['favorite_albums'] is List
            ? user['favorite_albums'] as List
            : null;

        await storageService.saveTokens(
          accessToken: (tokens['access'] ?? '').toString(),
          refreshToken: (tokens['refresh'] ?? '').toString(),
        );

        if (!mounted) return;
        final nextRoute = await SessionCoordinator.handleAuthenticatedUser(
          context,
          username: (user['username'] ?? googleUser.displayName ?? '').toString(),
          email: userEmail,
          isNewAccount: isNewUser,
          serverFavoriteArtists: serverArtists,
          serverSuperlikes: serverSuperlikes,
          serverFavoriteAlbums: serverFavoriteAlbums,
        );

        if (mounted) {
          context.go(nextRoute);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = _extractAuthError(
          e,
          fallback: "Erreur lors de l'inscription avec Google.",
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 15),
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF141419),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = _isLoading || _isGoogleLoading;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/login');
                        }
                      },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                    ),
                  ),

                  const Center(
                    child: SonoritizVectorLogo(
                      size: 62,
                      variant: SonoritizLogoVariant.standard,
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Créer votre compte',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Un profil personnel rien que pour vos artistes et écoutes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 19),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: _fieldDecoration(
                      hint: "Nom d'utilisateur",
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: _fieldDecoration(
                      hint: 'Adresse e-mail',
                      icon: Icons.mail_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: _fieldDecoration(
                      hint: 'Mot de passe (8 caractères min.)',
                      icon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.white54,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    onSubmitted: (_) => _register(),
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: _fieldDecoration(
                      hint: 'Confirmer le mot de passe',
                      icon: Icons.verified_user_outlined,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.white54,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _obscureConfirm = !_obscureConfirm);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Bouton Créer mon compte (orange -> texte NOIR)
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: busy ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Créer mon compte',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'ou',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
                    ],
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      onPressed: busy ? null : _registerWithGoogle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFF141419),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isGoogleLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GoogleLogoIcon(size: 20),
                                SizedBox(width: 12),
                                Text(
                                  "S'inscrire avec Google",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Déjà un compte ? ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => context.go('/login'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: const Text(
                          'Se connecter',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
