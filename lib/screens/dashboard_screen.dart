import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'installments_screen.dart';
import 'notifications_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Crédito'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && !provider.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && !provider.hasData) {
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

          final data = provider.dashboardData;
          if (data == null) return const SizedBox();

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CustomerCard(customer: data.customer, loan: data.loan),
                  const SizedBox(height: 16),
                  if (data.nextPayment != null) ...[
                    _NextPaymentCard(
                      installment: data.nextPayment!,
                      hasOverdue: data.hasOverduePayments,
                      overdueCount: data.overdueCount,
                      totalOverdue: data.totalOverdueAmount,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _LoanSummaryCard(loan: data.loan),
                  const SizedBox(height: 16),
                  if (data.deviceStatus != null)
                    _DeviceCard(deviceStatus: data.deviceStatus!),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.list_alt),
                      label: const Text('Ver Todas las Cuotas'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const InstallmentsScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final Loan loan;

  const _CustomerCard({required this.customer, required this.loan});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                customer.fullName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Contrato: ${loan.contractNumber}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextPaymentCard extends StatelessWidget {
  final Installment installment;
  final bool hasOverdue;
  final int overdueCount;
  final double totalOverdue;

  const _NextPaymentCard({
    required this.installment,
    required this.hasOverdue,
    required this.overdueCount,
    required this.totalOverdue,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = installment.isOverdue;
    final cardColor = isOverdue ? AppColors.error : AppColors.primary;

    return Card(
      color: cardColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOverdue ? 'PAGO VENCIDO' : 'PRÓXIMO PAGO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cardColor,
                    letterSpacing: 1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Cuota #${installment.installmentNumber}',
                    style: TextStyle(
                      color: cardColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              Formatters.currency(installment.amount),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: cardColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 16, color: cardColor),
                const SizedBox(width: 8),
                Text(
                  'Vence: ${Formatters.date(installment.dueDate)}',
                  style: TextStyle(
                    fontSize: 15,
                    color: cardColor,
                  ),
                ),
              ],
            ),
            if (isOverdue) ...[
              const SizedBox(height: 8),
              Text(
                '${installment.daysOverdue} días de atraso',
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (hasOverdue && overdueCount > 1) ...[
              const Divider(height: 24),
              Text(
                'Total vencido: ${Formatters.currency(totalOverdue)} ($overdueCount cuotas)',
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoanSummaryCard extends StatelessWidget {
  final Loan loan;

  const _LoanSummaryCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    final progress = 1 - (loan.financedAmount / loan.totalAmount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen del Préstamo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow('Monto Total', Formatters.currency(loan.totalAmount)),
            _InfoRow('Prima', Formatters.currency(loan.downPaymentAmount)),
            _InfoRow('Monto Financiado', Formatters.currency(loan.financedAmount)),
            _InfoRow('Cuotas', '${loan.numberOfInstallments} meses'),
            _InfoRow('Tasa de Interés', '${loan.interestRate}% anual'),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                color: AppColors.success,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% pagado',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceStatus deviceStatus;

  const _DeviceCard({required this.deviceStatus});

  @override
  Widget build(BuildContext context) {
    final isBlocked = deviceStatus.isBlocked;

    return Card(
      child: ListTile(
        leading: Icon(
          Icons.phone_android,
          color: isBlocked ? AppColors.error : AppColors.success,
          size: 32,
        ),
        title: Text(deviceStatus.phoneModel),
        subtitle: Text(
          isBlocked ? 'Dispositivo bloqueado' : 'Dispositivo activo',
          style: TextStyle(
            color: isBlocked ? AppColors.error : AppColors.success,
          ),
        ),
        trailing: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isBlocked ? AppColors.error : AppColors.success,
          ),
        ),
      ),
    );
  }
}
