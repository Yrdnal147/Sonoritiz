import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/session_coordinator.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sonoritiz_brand_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _extractDioError(Object e, {String fallback = 'Erreur de connexion au serveur.'}) {
    if (e is DioException && e.response?.data is Map) {
      final errData = e.response!.data as Map;
      if (errData['non_field_errors'] != null && errData['non_field_errors'] is List) {
        return (errData['non_field_errors'] as List).join('\n');
      }
      if (errData['detail'] != null) return errData['detail'].toString();
      if (errData['error'] != null) return errData['error'].toString();
    } else if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Le serveur met trop de temps à répondre. Veuillez réessayer.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Impossible de se connecter au serveur. Vérifiez votre connexion.';
      }
    }
    return fallback;
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir votre e-mail et votre mot de passe.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storageService = StorageService();
      final apiClient = ApiClient(storageService: storageService);

      final response = await apiClient.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data as Map? ?? const {};
        final tokens = (data['tokens'] is Map) ? data['tokens'] as Map : const {};
        await storageService.saveTokens(
          accessToken: (tokens['access'] ?? '').toString(),
          refreshToken: (tokens['refresh'] ?? '').toString(),
        );

        final user = (data['user'] is Map) ? data['user'] as Map : const {};
        final serverArtists = user['favorite_artists'] is List
            ? user['favorite_artists'] as List
            : null;

        if (!mounted) return;
        final nextRoute = await SessionCoordinator.handleAuthenticatedUser(
          context,
          username: (user['username'] ?? '').toString(),
          email: (user['email'] ?? email).toString(),
          isNewAccount: false,
          serverFavoriteArtists: serverArtists,
        );

        if (mounted) {
          context.go(nextRoute);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = _extractDioError(e);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId:
            '332358147050-fj2huukn8hcf40dukiuta1hc393lmh5a.apps.googleusercontent.com',
      );
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        setState(() {
          _errorMessage = "Impossible d'obtenir le jeton Google. Veuillez réessayer.";
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
        final data = response.data as Map? ?? const {};
        final bool isNewUser = data['is_new_user'] == true;
        final user = (data['user'] is Map) ? data['user'] as Map : const {};
        final userEmail = (user['email'] ?? googleUser.email).toString();
        final tokens = (data['tokens'] is Map) ? data['tokens'] as Map : const {};
        final serverArtists = user['favorite_artists'] is List
            ? user['favorite_artists'] as List
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
        );

        if (mounted) {
          context.go(nextRoute);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = _extractDioError(
          e,
          fallback: 'Erreur lors de la connexion avec Google.',
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
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
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // Logo centré épuré sans lueur ni bordure
                  const Center(
                    child: SonoritizVectorLogo(
                      size: 74,
                      variant: SonoritizLogoVariant.standard,
                    ),
                  ),
                  const SizedBox(height: 22),

                  const Text(
                    'Content de vous retrouver',
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
                    'Connectez-vous à votre espace musical personnel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 14.5,
                    ),
                  ),

                  const SizedBox(height: 30),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.45),
                        ),
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
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: _fieldDecoration(
                      hint: 'Adresse e-mail',
                      icon: Icons.mail_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onSubmitted: (_) => _login(),
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: _fieldDecoration(
                      hint: 'Mot de passe',
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

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: busy ? null : () => context.push('/forgot-password'),
                      child: const Text(
                        'Mot de passe oublié ?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Bouton Se connecter (orange -> texte NOIR)
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: busy ? null : _login,
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
                              'Se connecter',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
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
                  const SizedBox(height: 22),

                  // Bouton Google avec le véritable logo Google G 4 couleurs
                  SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      onPressed: busy ? null : _loginWithGoogle,
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
                                  'Continuer avec Google',
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

                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Nouveau sur Sonoritiz ? ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => context.push('/register'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: const Text(
                          "S'inscrire",
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
