import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/installments_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'payment_screen.dart';

class InstallmentsScreen extends StatefulWidget {
  const InstallmentsScreen({super.key});

  @override
  State<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends State<InstallmentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InstallmentsProvider>().loadInstallments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Cuotas'),
      ),
      body: Consumer<InstallmentsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.installments.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.installments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(provider.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.refresh(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: Column(
              children: [
                if (provider.summary != null)
                  _SummaryHeader(summary: provider.summary!),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.installments.length,
                    itemBuilder: (context, index) {
                      final installment = provider.installments[index];
                      return _InstallmentCard(installment: installment);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final InstallmentSummary summary;

  const _SummaryHeader({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem('Pagadas', summary.paid, AppColors.success),
          _SummaryItem('Pendientes', summary.pending, Colors.white),
          _SummaryItem('Vencidas', summary.overdue, AppColors.warning),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  final Installment installment;

  const _InstallmentCard({required this.installment});

  Color get _statusColor {
    switch (installment.status) {
      case InstallmentStatus.paid:
        return AppColors.success;
      case InstallmentStatus.overdue:
        return AppColors.error;
      case InstallmentStatus.pending:
        return AppColors.primary;
    }
  }

  IconData get _statusIcon {
    switch (installment.status) {
      case InstallmentStatus.paid:
        return Icons.check_circle;
      case InstallmentStatus.overdue:
        return Icons.warning;
      case InstallmentStatus.pending:
        return Icons.schedule;
    }
  }

  String get _statusText {
    switch (installment.status) {
      case InstallmentStatus.paid:
        return 'Pagada';
      case InstallmentStatus.overdue:
        return 'Vencida';
      case InstallmentStatus.pending:
        return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: installment.isPaid
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentScreen(installment: installment),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_statusIcon, color: _statusColor),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cuota #${installment.installmentNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          Formatters.currency(installment.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          installment.isPaid && installment.paidDate != null
                              ? 'Pagada: ${Formatters.date(installment.paidDate!)}'
                              : 'Vence: ${Formatters.date(installment.dueDate)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _statusText,
                            style: TextStyle(
                              color: _statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (installment.isOverdue) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${installment.daysOverdue} días de atraso',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!installment.isPaid) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
