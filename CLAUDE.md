# CLAUDE.md - MOVICUOTAS Mobile

## Contexto del Proyecto

**MOVICUOTAS Mobile** es una aplicación Flutter simple de **solo consulta** para clientes del sistema de créditos de dispositivos móviles. La app permite a los clientes ver información básica sobre su crédito actual.

### Funcionalidad Core (Simple y Directa)

Esta NO es una app compleja. Es básicamente:

1. **Login**: Identidad + Número de Contrato
2. **Ver Info del Usuario**: Nombre, contrato, dispositivo
3. **Ver Cuota Actual**: Próximo pago pendiente
4. **Ver Historial de Pagos**: Lista de pagos realizados

**No incluye**: Pagos en línea, notificaciones push complejas, MDM, funcionalidad offline avanzada, ni gestión de préstamos.

### Objetivo del Sistema

Proporcionar a los clientes una forma simple y rápida de consultar el estado de su crédito sin necesidad de llamar a la tienda o visitar en persona.

## Arquitectura del Sistema

### Arquitectura General

```
┌─────────────────────────────────────────┐
│     MOVICUOTAS Mobile (Flutter)         │
│  ┌───────────────────────────────────┐  │
│  │   Presentation Layer              │  │
│  │   - Screens                       │  │
│  │   - Widgets                       │  │
│  │   - State Management (Provider)   │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │   Domain Layer                    │  │
│  │   - Entities                      │  │
│  │   - Use Cases                     │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │   Data Layer                      │  │
│  │   - Repositories                  │  │
│  │   - API Clients (Dio)             │  │
│  │   - Local Storage (Hive/SQLite)   │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
                    ↕ (REST API / JWT)
┌─────────────────────────────────────────┐
│   MOVICUOTAS Backend (Rails 8)          │
│   - API REST                            │
│   - Autenticación JWT                   │
│   - Gestión de préstamos                │
│   - MDM Integration                     │
└─────────────────────────────────────────┘
```

### Stack Técnico (Minimalista)

- **Frontend**: Flutter 3.x + Dart 3.x
- **State Management**: Provider (simple y suficiente)
- **Networking**: Dio (HTTP client)
- **Cookie Management**: Cookie Jar + Dio Cookie Manager
- **Autenticación**: Sesiones Rails (cookie-based, HTTP-only)

## Modelos de Datos (Solo Lectura)

La app solo **lee** estos datos, nunca los modifica:

### Customer (Cliente) - Info Básica

```dart
class Customer {
  final String id;
  final String identityNumber;      // Número de identidad para login
  final String customerNumber;      // Número de cliente interno
  final String firstName;
  final String lastName;
  final String phone;

  String get fullName => '$firstName $lastName';
}
```

### Loan (Préstamo Activo)

```dart
class Loan {
  final String id;
  final String contractNumber;      // Mostrar al cliente
  final double loanAmount;          // Monto total original
  final double remainingBalance;    // Lo que falta pagar
  final int termMonths;             // Plazo en meses
  final DateTime startDate;
  final DateTime endDate;

  // Info del dispositivo (solo para mostrar)
  final String deviceName;          // ej: "iPhone 13 Pro 128GB"
}
```

### Installment (Cuota Actual)

```dart
class Installment {
  final String id;
  final int installmentNumber;      // ej: 3 (cuota #3)
  final double amount;              // Monto de la cuota
  final DateTime dueDate;           // Fecha de vencimiento
  final InstallmentStatus status;   // pending, paid, overdue

  bool get isOverdue => status == InstallmentStatus.overdue;
  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;
}

enum InstallmentStatus {
  pending,   // Pendiente
  paid,      // Pagada
  overdue    // Vencida
}
```

### Payment (Historial)

```dart
class Payment {
  final String id;
  final double amount;
  final DateTime paymentDate;
  final String method;              // "Efectivo", "Transferencia", etc.
  final String receiptNumber;       // Número de recibo
  final int installmentNumber;      // A qué cuota corresponde

  String get formattedDate => DateFormat('dd/MM/yyyy').format(paymentDate);
  String get formattedAmount => 'L ${amount.toStringAsFixed(2)}';
}
```

## Flujos de Trabajo (Simples)

### 1. Login → Dashboard (Con Cookies Rails)

```dart
// login_screen.dart
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identityController = TextEditingController();
  final _contractController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      // POST /login
      // Rails automáticamente establece la cookie de sesión
      final response = await apiClient.post('/login', {
        'identity_number': _identityController.text,
        'contract_number': _contractController.text,
      });

      // ¡No hay que guardar nada manualmente!
      // CookieJar persiste la cookie automáticamente

      // Navegar a dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Credenciales incorrectas')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('MOVICUOTAS', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            SizedBox(height: 48),
            TextField(
              controller: _identityController,
              decoration: InputDecoration(labelText: 'Número de Identidad'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _contractController,
              decoration: InputDecoration(labelText: 'Número de Contrato'),
              obscureText: true,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading ? CircularProgressIndicator() : Text('Iniciar Sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 2. Dashboard (Pantalla Principal)

```dart
// dashboard_screen.dart
class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mi Crédito')),
      body: FutureBuilder<DashboardData>(
        future: _loadDashboardData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Info del cliente
                Card(
                  child: ListTile(
                    leading: Icon(Icons.person),
                    title: Text(data.customer.fullName),
                    subtitle: Text('Contrato: ${data.loan.contractNumber}'),
                  ),
                ),

                SizedBox(height: 16),

                // Cuota actual
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('PRÓXIMO PAGO', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('L ${data.currentInstallment.amount}',
                             style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                        Text('Vence: ${_formatDate(data.currentInstallment.dueDate)}'),
                        Text('Cuota #${data.currentInstallment.installmentNumber}'),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Saldo pendiente
                Card(
                  child: ListTile(
                    leading: Icon(Icons.account_balance_wallet),
                    title: Text('Saldo Pendiente'),
                    trailing: Text('L ${data.loan.remainingBalance}',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),

                SizedBox(height: 16),

                // Botón historial
                ElevatedButton.icon(
                  icon: Icon(Icons.history),
                  label: Text('Ver Historial de Pagos'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PaymentHistoryScreen()),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<DashboardData> _loadDashboardData() async {
    // Hacer 3 llamadas a la API
    final responses = await Future.wait([
      apiClient.get('/customers/me'),
      apiClient.get('/loans/active'),
      apiClient.get('/installments/current'),
    ]);

    return DashboardData(
      customer: Customer.fromJson(responses[0]),
      loan: Loan.fromJson(responses[1]),
      currentInstallment: Installment.fromJson(responses[2]),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class DashboardData {
  final Customer customer;
  final Loan loan;
  final Installment currentInstallment;

  DashboardData({
    required this.customer,
    required this.loan,
    required this.currentInstallment,
  });
}
```

### 3. Historial de Pagos

```dart
// payment_history_screen.dart
class PaymentHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Historial de Pagos')),
      body: FutureBuilder<List<Payment>>(
        future: _loadPayments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final payments = snapshot.data!;

          if (payments.isEmpty) {
            return Center(child: Text('No hay pagos registrados'));
          }

          return ListView.builder(
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.check, color: Colors.white),
                  ),
                  title: Text('L ${payment.amount.toStringAsFixed(2)}'),
                  subtitle: Text(
                    'Cuota #${payment.installmentNumber}\n'
                    '${payment.method}\n'
                    'Recibo: ${payment.receiptNumber}'
                  ),
                  trailing: Text(payment.formattedDate),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Payment>> _loadPayments() async {
    final response = await apiClient.get('/payments/history');
    return (response['payments'] as List)
        .map((json) => Payment.fromJson(json))
        .toList();
  }
}
```

## Estructura del Proyecto (Simple)

```
lib/
├── main.dart                 # Entry point
├── models/
│   ├── customer.dart        # Modelo del cliente
│   ├── loan.dart            # Modelo del préstamo
│   ├── installment.dart     # Modelo de cuota
│   └── payment.dart         # Modelo de pago
├── screens/
│   ├── login_screen.dart    # Pantalla de login
│   ├── dashboard_screen.dart # Pantalla principal
│   └── payment_history_screen.dart # Historial
├── services/
│   └── api_client.dart      # Cliente HTTP (Dio + CookieJar)
└── utils/
    ├── constants.dart        # Constantes (colores, URLs)
    └── formatters.dart       # Helpers (formatear fechas, montos)
```

**Nota**: No necesitamos carpeta de storage ni SharedPreferences porque las cookies se manejan automáticamente con CookieJar.

## API Client con Cookies (Rails Way)

```dart
// services/api_client.dart
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';

class ApiClient {
  static const String baseUrl = 'https://api.movicuotas.com';
  late final Dio _dio;
  late final CookieJar _cookieJar;

  ApiClient() {
    _initializeCookieJar();
  }

  Future<void> _initializeCookieJar() async {
    // Guardar cookies en disco para persistencia
    final appDocDir = await getApplicationDocumentsDirectory();
    final appDocPath = appDocDir.path;
    _cookieJar = PersistCookieJar(
      storage: FileStorage(appDocPath + "/.cookies/"),
    );

    // Configurar Dio
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Agregar interceptor de cookies
    // Esto maneja automáticamente las cookies en todas las requests
    _dio.interceptors.add(CookieManager(_cookieJar));

    // Logging (opcional, para desarrollo)
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  // Login - Rails establece la cookie automáticamente
  Future<Map<String, dynamic>> login(String identity, String contract) async {
    final response = await _dio.post('/login', data: {
      'identity_number': identity,
      'contract_number': contract,
    });
    // La cookie de sesión se guarda automáticamente por CookieManager
    return response.data;
  }

  // Logout - Rails destruye la cookie
  Future<void> logout() async {
    await _dio.post('/logout');
    // Limpiar cookies localmente también
    await _cookieJar.deleteAll();
  }

  // Get customer info - La cookie se envía automáticamente
  Future<Map<String, dynamic>> getCustomer() async {
    final response = await _dio.get('/customers/me');
    return response.data;
  }

  // Get active loan
  Future<Map<String, dynamic>> getActiveLoan() async {
    final response = await _dio.get('/loans/active');
    return response.data;
  }

  // Get current installment
  Future<Map<String, dynamic>> getCurrentInstallment() async {
    final response = await _dio.get('/installments/current');
    return response.data;
  }

  // Get payment history
  Future<List<dynamic>> getPaymentHistory() async {
    final response = await _dio.get('/payments/history');
    return response.data['payments'];
  }
}

// Singleton para reutilizar en toda la app
final apiClient = ApiClient();
```

### Ventajas de Usar Cookies vs JWT

1. **Más Simple**: No hay que manejar tokens manualmente
2. **Rails Way**: Usa el sistema nativo de sesiones de Rails 8
3. **Automático**: CookieJar maneja todo (guardar, enviar, actualizar)
4. **Seguro**: Cookies HTTP-only (no accesibles desde JavaScript)
5. **Persistente**: PersistCookieJar guarda en disco automáticamente

## Decisiones de Diseño

### 1. App Simple de Solo Consulta

**Decisión**: Crear una app minimalista de solo lectura, sin funcionalidades complejas.

**Razones**:
- El cliente necesita algo funcional y rápido
- Los pagos se hacen en persona, no en línea
- Reduce tiempo de desarrollo y mantenimiento
- Más fácil de probar y debuggear

### 2. Sesiones Rails con Cookies vs JWT

**Decisión**: Usar el sistema de autenticación nativo de Rails 8 con sesiones basadas en cookies HTTP-only en lugar de JWT.

**Razones**:
- **Rails Way**: Usa el sistema estándar de Rails 8
- **Más Simple**: No hay que manejar tokens manualmente en Flutter
- **Automático**: CookieJar + Dio manejan todo sin código adicional
- **Seguro**: Cookies HTTP-only no son accesibles desde código
- **Persistente**: PersistCookieJar guarda cookies automáticamente en disco

**Comparación**:
```dart
// Con JWT (más complejo)
await prefs.setString('token', response['token']);
options.headers['Authorization'] = 'Bearer $token';

// Con Cookies (automático)
// ¡No hay código! CookieManager lo hace todo
```

### 3. Autenticación con Identidad + Contrato

**Decisión**: Usar número de identidad + número de contrato en lugar de email/password.

**Razones**:
- Inspirado en sistemas de crédito conocidos como KrediYa (Honduras)
- Más intuitivo para clientes sin experiencia técnica
- El contrato es único y ya está en poder del cliente
- No requiere memorizar passwords complicados

### 4. Sin Arquitectura Compleja

**Decisión**: No usar Clean Architecture, Repository Pattern, ni Use Cases.

**Razones**:
- La app es demasiado simple para justificar la complejidad
- 3 pantallas no requieren abstracción avanzada
- Más fácil de mantener con código directo
- Tiempo de desarrollo se reduce significativamente

### 5. Color #125282 como Color Primario

**Decisión**: Usar azul oscuro #125282 como color principal de la marca.

**Razones**:
- Psicología del color: confianza, profesionalismo, estabilidad
- Apropiado para aplicaciones financieras
- Buen contraste con texto blanco (accesibilidad)

## Testing (Básico pero Suficiente)

Para una app simple de consulta, nos enfocamos en tests básicos:

### Widget Tests (Lo Esencial)

```dart
// test/widgets/dashboard_test.dart
void main() {
  testWidgets('Dashboard muestra cuota actual', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen()),
    );

    // Verificar que se muestra la cuota
    expect(find.text('PRÓXIMO PAGO'), findsOneWidget);
    expect(find.text('L '), findsWidgets); // Debería haber varios montos
  });
}
```

### Integration Test (Login → Dashboard)

```dart
// integration_test/app_test.dart
void main() {
  testWidgets('Flujo completo login a dashboard', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Login
    await tester.enterText(find.byType(TextField).first, '0801199012345');
    await tester.enterText(find.byType(TextField).last, 'S01-2025-12-04-000001');
    await tester.tap(find.text('Iniciar Sesión'));
    await tester.pumpAndSettle();

    // Verificar que llegó al dashboard
    expect(find.text('Mi Crédito'), findsOneWidget);
  });
}
```

## Deployment (Android APK)

```bash
# Build APK para testing
flutter build apk --debug

# Build APK para producción
flutter build apk --release

# El APK estará en:
# build/app/outputs/flutter-apk/app-release.apk
```

## Próximos Pasos (Ruta Rápida)

### Semana 1: Setup y Login
- [x] Crear proyecto Flutter
- [ ] Implementar LoginScreen
- [ ] Integrar con API /auth/login
- [ ] Guardar token en SharedPreferences

### Semana 2: Dashboard
- [ ] Crear DashboardScreen
- [ ] Mostrar info del cliente
- [ ] Mostrar cuota actual (card destacado)
- [ ] Mostrar saldo pendiente
- [ ] Agregar botón "Ver Historial"

### Semana 3: Historial
- [ ] Crear PaymentHistoryScreen
- [ ] Listar todos los pagos
- [ ] Formatear montos y fechas
- [ ] Scroll infinito (si hay muchos pagos)

### Semana 4: Polish y Testing
- [ ] Agregar loading indicators
- [ ] Manejo de errores (sin conexión, etc)
- [ ] Tests básicos
- [ ] Build APK para testing con cliente

## Dependencias Necesarias (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # HTTP Client
  dio: ^5.4.0

  # Cookie Management (para sesiones Rails)
  dio_cookie_manager: ^3.1.0
  cookie_jar: ^4.0.8

  # Storage para cookies persistentes
  path_provider: ^2.1.0

  # Utilidades
  intl: ^0.19.0  # Para formatear fechas y montos

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
```

## Colores y Tema (utils/constants.dart)

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF125282);
  static const success = Color(0xFF10b981);
  static const warning = Color(0xFFf59e0b);
  static const error = Color(0xFFef4444);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    primaryColor: AppColors.primary,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
    ),
  );
}
```

## Recursos

- **Backend Repo**: `movicuotas-backend` (Rails 8)
- **Design System**: Ver documento de colores y branding
- **Flutter Docs**: https://flutter.dev/docs
- **Dio Package**: https://pub.dev/packages/dio

## Notas Importantes

**Esta es una app SIMPLE:**
- Solo 3 pantallas (Login, Dashboard, Historial)
- Solo lectura (no se crean ni modifican datos)
- No requiere arquitectura compleja
- Enfoque en simplicidad y rapidez de desarrollo
- Los pagos se hacen en persona, no en la app

**Prioridades:**
1. Que funcione bien
2. Que sea rápida
3. Que sea fácil de usar
4. Que sea fácil de mantener

---

**Última actualización**: Diciembre 2024
**Proyecto**: MOVICUOTAS - Sistema de Gestión de Créditos
