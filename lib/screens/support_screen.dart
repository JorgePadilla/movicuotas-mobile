import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../utils/constants.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const _fallbackPhone = '97902401';

  String _phoneNumber = _fallbackPhone;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSupportPhone();
  }

  Future<void> _loadSupportPhone() async {
    final settings = await ApiClient().getSettings();
    final phone = settings['support_phone_number'] as String?;
    if (mounted) {
      setState(() {
        if (phone != null && phone.isNotEmpty) {
          _phoneNumber = phone;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soporte'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Icon
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.support_agent,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Title
                  const Text(
                    'Estamos para ayudarte',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Description
                  const Text(
                    'Para cualquier pregunta sobre su préstamo, pagos o estado de su dispositivo, puede comunicarse con nosotros al siguiente número:',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Phone number card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.phone,
                            size: 32,
                            color: AppColors.success,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _phoneNumber,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Schedule info
                  const Text(
                    'Horario de atención:\nLunes a Viernes 8:00 AM - 5:00 PM\nSábado 8:00 AM - 12:00 PM',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}
