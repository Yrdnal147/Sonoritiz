import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/constants/api_constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../library/presentation/cubit/library_cubit.dart';
import '../../offline/presentation/cubit/download_cubit.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Veuillez remplir tous les champs.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storageService = StorageService();
      await storageService.init();
      final apiClient = ApiClient(storageService: storageService);

      final response = await apiClient.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        final tokens = data['tokens'] ?? {};
        await storageService.saveTokens(
          accessToken: tokens['access'] ?? '',
          refreshToken: tokens['refresh'] ?? '',
        );
        if (data.containsKey('user')) {
          await storageService.saveUserInfo(
            username: data['user']['username'] ?? '',
            email: data['user']['email'] ?? email,
          );
        }

        if (mounted) {
          context.read<LibraryCubit>().loadLibraryData();
          context.read<DownloadCubit>().loadDownloads();
          context.go('/home');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // IMPORTANT : Il faut utiliser un Web Client ID (et non l'Android Client ID) 
      // pour obtenir le idToken à envoyer au backend Django.
      final googleSignIn = GoogleSignIn(
        serverClientId: '332358147050-fj2huukn8hcf40dukiuta1hc393lmh5a.apps.googleusercontent.com',
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled login
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception("Impossible de récupérer le token Google.");
      }

      final storageService = StorageService();
      await storageService.init();
      final apiClient = ApiClient(storageService: storageService);

      final response = await apiClient.post(ApiConstants.googleLogin, data: {
        'id_token': idToken,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        final tokens = data['tokens'] ?? {};
        await storageService.saveTokens(
          accessToken: tokens['access'] ?? '',
          refreshToken: tokens['refresh'] ?? '',
        );
        if (data.containsKey('user')) {
          await storageService.saveUserInfo(
            username: data['user']['username'] ?? '',
            email: data['user']['email'] ?? googleUser.email,
          );
        }

        if (mounted) {
          context.read<LibraryCubit>().loadLibraryData();
          context.read<DownloadCubit>().loadDownloads();
          context.go('/home');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur de connexion Google : ${e.toString()}";
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.12),
                // Logo & Title
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.music_note, size: 48, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    "Sonoritiz",
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.2),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    "Connecte-toi pour continuer",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 48),

                // Error message
                if (_errorMessage != null)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                // Email field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Email",
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),

                // Password field
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: "Mot de passe",
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Forgot Password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text(
                      "Mot de passe oublié ?",
                      style: TextStyle(color: AppColors.primary, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Login button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text("Se connecter", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),

                // Google Login button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _googleLogin,
                    icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.white),
                    label: const Text("Continuer avec Google", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Register link
                TextButton(
                  onPressed: () => context.push('/register'),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      text: "Pas encore de compte ? ",
                      style: TextStyle(color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                          text: "S'inscrire",
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );


  }
}
