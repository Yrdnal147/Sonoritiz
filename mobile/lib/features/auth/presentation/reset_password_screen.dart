import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/constants/api_constants.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;
  const ResetPasswordScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isError = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitNewPassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (password.isEmpty || confirm.isEmpty) {
      setState(() {
        _message = "Veuillez remplir tous les champs.";
        _isError = true;
      });
      return;
    }

    if (password != confirm) {
      setState(() {
        _message = "Les mots de passe ne correspondent pas.";
        _isError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final storageService = StorageService();
      final apiClient = ApiClient(storageService: storageService);

      final response = await apiClient.post(ApiConstants.passwordResetConfirm, data: {
        'token': widget.token,
        'new_password': password,
      });

      if (response.statusCode == 200) {
        setState(() {
          _message = "Votre mot de passe a été réinitialisé avec succès !";
          _isError = false;
        });
        
        // Return to login after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) context.go('/login');
        });
      }
    } catch (e) {
      setState(() {
        _message = e.toString();
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  "Nouveau mot de passe",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  "Créez un nouveau mot de passe (8 caractères minimum).",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
              const SizedBox(height: 48),

              if (_message != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isError ? AppColors.error.withOpacity(0.15) : AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isError ? AppColors.error.withOpacity(0.3) : AppColors.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(_isError ? Icons.error_outline : Icons.check_circle_outline, 
                           color: _isError ? AppColors.error : AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_message!, style: TextStyle(color: _isError ? AppColors.error : AppColors.success, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Nouveau mot de passe",
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
              const SizedBox(height: 16),

              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Confirmer le mot de passe",
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 32),

              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitNewPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text("Réinitialiser", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
