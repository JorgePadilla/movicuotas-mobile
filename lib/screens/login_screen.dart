import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import 'activation_success_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  /// Whether this login is part of the activation flow (after device activation)
  final bool isActivationFlow;

  const LoginScreen({super.key, this.isActivationFlow = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();
  bool _rememberSession = true;

  // Mask for identity: 0000-0000-00000 (13 digits)
  final _identityMask = MaskTextInputFormatter(
    mask: '####-####-#####',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void dispose() {
    _identityController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Remove dashes from identity
    final identity = _identityController.text.replaceAll('-', '').trim();

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      identificationNumber: identity,
      rememberSession: _rememberSession,
    );

    if (success && mounted) {
      if (widget.isActivationFlow) {
        // Activation flow: show success screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ActivationSuccessScreen()),
        );
      } else {
        // Normal login (JWT expired): go directly to dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } else if (mounted && authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // Logo/Title
                Image.asset(
                  'assets/icon/app_icon.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 24),
                const Text(
                  'MOVICUOTAS',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Consulta tu crédito',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),

                // Identity Field with mask
                TextFormField(
                  controller: _identityController,
                  decoration: const InputDecoration(
                    labelText: 'Número de Identidad',
                    hintText: '0000-0000-00000',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [_identityMask],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu número de identidad';
                    }
                    // Check if all 13 digits are entered
                    final digits = value.replaceAll('-', '');
                    if (digits.length < 13) {
                      return 'Ingresa los 13 dígitos de tu identidad';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Remember session checkbox
                CheckboxListTile(
                  value: _rememberSession,
                  onChanged: (value) => setState(() => _rememberSession = value ?? true),
                  title: const Text(
                    'Mantener sesión iniciada',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'No tendrás que ingresar tus datos la próxima vez',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                ),

                const SizedBox(height: 16),

                // Login Button
                Consumer<AuthProvider>(
                  builder: (context, auth, child) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _handleLogin,
                        child: auth.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Iniciar Sesión',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Help Text
                const Text(
                  'Ingresa tu número de identidad\npara consultar tu crédito.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
