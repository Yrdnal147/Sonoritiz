import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/constants/api_constants.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _message = "Veuillez entrer votre adresse e-mail.";
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

      final response = await apiClient.post(ApiConstants.passwordReset, data: {
        'email': email,
      });

      if (response.statusCode == 200) {
        setState(() {
          _message = "Si ce compte existe, un e-mail de réinitialisation a été envoyé.";
          _isError = false;
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
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
                  "Mot de passe oublié",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  "Entrez votre adresse e-mail. Si elle est associée à un compte, nous vous enverrons un lien pour réinitialiser votre mot de passe.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
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
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Email",
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 32),

              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text("Envoyer le lien", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
