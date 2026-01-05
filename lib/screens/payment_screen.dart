import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/installments_provider.dart';
import '../services/api_client.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class PaymentScreen extends StatefulWidget {
  final Installment installment;

  const PaymentScreen({super.key, required this.installment});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  File? _receiptImage;
  bool _isSubmitting = false;
  DateTime _paymentDate = DateTime.now();

  final _apiClient = ApiClient();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.installment.amount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        _receiptImage = File(picked.path);
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar Foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de Galería'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _paymentDate = picked;
      });
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text);

      final result = await _apiClient.submitPayment(
        installmentId: widget.installment.id,
        amount: amount,
        paymentDate: _paymentDate,
        receiptImage: _receiptImage,
      );

      if (mounted) {
        // Refresh installments
        context.read<InstallmentsProvider>().refresh();

        // Show success and go back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Pago enviado correctamente'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pagar Cuota #${widget.installment.installmentNumber}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Installment Info Card
              Card(
                color: AppColors.primary.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Cuota a pagar'),
                          Text(
                            '#${widget.installment.installmentNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Monto'),
                          Text(
                            Formatters.currency(widget.installment.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Fecha de vencimiento'),
                          Text(
                            Formatters.date(widget.installment.dueDate),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Amount Field
              const Text(
                'Monto a Pagar',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  prefixText: 'L ',
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa el monto';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Ingresa un monto válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Payment Date
              const Text(
                'Fecha de Pago',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(Formatters.date(_paymentDate)),
                ),
              ),
              const SizedBox(height: 24),

              // Receipt Image
              const Text(
                'Comprobante de Pago (Opcional)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Adjunta una foto de tu recibo de pago o transferencia',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (_receiptImage != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _receiptImage!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                        onPressed: () => setState(() => _receiptImage = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.add_a_photo),
                label: Text(_receiptImage != null ? 'Cambiar Imagen' : 'Agregar Imagen'),
                onPressed: _showImageSourceDialog,
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPayment,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Enviar Pago',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Info Text
              const Card(
                color: Color(0xFFFFF3CD),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF856404)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tu pago quedará pendiente de verificación. Recibirás una notificación cuando sea confirmado.',
                          style: TextStyle(color: Color(0xFF856404), fontSize: 13),
                        ),
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
