import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'providers/providers.dart';
import 'screens/screens.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';

/// Global navigator key for navigation from notification taps
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  // Initialize Firebase and FCM
  final notificationService = NotificationService();
  await notificationService.initialize(
    onNotificationTap: _handleNotificationTap,
  );

  // Save FCM token to a file for easy access
  final token = notificationService.fcmToken ?? 'NO_TOKEN';
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/fcm_token.txt');
    await file.writeAsString(token);
    print('FCM Token saved to: ${file.path}');
  } catch (e) {
    print('Could not save token to file: $e');
  }

  // Also print to console
  print('');
  print('############################################');
  print('FCM TOKEN: $token');
  print('############################################');
  print('');

  runApp(const MovicuotasApp());
}

/// Handle notification tap navigation
void _handleNotificationTap(String type) {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  switch (type) {
    case 'payment_reminder':
    case 'payment_overdue':
      // Navigate to installments screen
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const InstallmentsScreen()),
      );
      break;
    case 'payment_confirmed':
      // Navigate to notifications screen
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
      break;
    default:
      // Default: navigate to dashboard
      break;
  }
}

class MovicuotasApp extends StatelessWidget {
  const MovicuotasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => InstallmentsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'MOVICUOTAS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.checkAuthStatus();

    if (!mounted) return;

    // Navigate based on auth status
    if (authProvider.isAuthenticated) {
      // Has valid JWT → Dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      // No JWT → Activation flow
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ActivationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      ),
    );
  }
}
