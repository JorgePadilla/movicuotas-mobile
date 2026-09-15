# CLAUDE.md - MOVICUOTAS Mobile

App Flutter para clientes de MOVICUOTAS (créditos de teléfonos). Consume la API
móvil del repo hermano `movicuotas-backend` (Rails 8) en `https://movicuotas.com/api/v1`.

> Este archivo describe el código **tal como está**. Si cambias auth, tokens FCM o
> endpoints, actualízalo. (La versión anterior describía un diseño con cookies y
> login por contrato que nunca se implementó.)

## Qué hace la app

1. **Activación** del teléfono con el código de 6 caracteres del contrato
   (`POST /devices/activate`). Vincula el token FCM al dispositivo y devuelve un JWT.
2. **Login por identidad** (`POST /auth/login`, solo `identification_number`;
   no hay contraseña ni número de contrato). Devuelve JWT de 30 días.
3. **Dashboard**: cliente, préstamo, próxima cuota, estado del dispositivo.
4. **Cuotas** e historial; **reporte de pago** con foto del recibo (`POST /payments`).
5. **Notificaciones push (FCM)**: recordatorios de pago (3 días antes, 1 día
   antes, el día) y avisos de mora, enviados por el backend a las 8am. Pantalla de
   notificaciones (`GET /notifications`).
6. Pantalla de soporte (teléfono / horario).

## Stack

- Flutter / Dart ^3.9, `provider` para estado, `dio` para HTTP.
- `flutter_secure_storage`: JWT, `customer_id`, `device_activated`, `remember_session`.
- `firebase_core` + `firebase_messaging` (push) + `flutter_local_notifications`
  (solo para mostrar mensajes FCM en primer plano; **no** hay notificaciones locales
  programadas).
- `device_info_plus` / `package_info_plus`: metadatos que se mandan al registrar el token.
- `google-services.json` **no** está en git; pedirlo antes de compilar.

## Estructura

```
lib/
├── main.dart                  # Firebase/FCM init, SplashScreen → ruta según estado
├── models/                    # Customer, Loan, Installment, Device, Notification, Dashboard
├── providers/                 # AuthProvider, DashboardProvider, InstallmentsProvider, NotificationsProvider
├── screens/                   # activation, activation_success, login, dashboard,
│                              # installments, payment, notifications, support
├── services/
│   ├── api_client.dart        # Dio + interceptor Bearer JWT; todos los endpoints
│   ├── notification_service.dart  # Singleton FCM: permisos, token, foreground, taps
│   └── storage_service.dart   # flutter_secure_storage
└── utils/                     # constants.dart (ApiConfig, colores), formatters.dart
```

Cada provider crea su **propio** `ApiClient`; por eso el JWT de la sesión vive en
un campo `static` de `ApiClient` (ver abajo).

## Autenticación y sesión (cómo funciona de verdad)

- **JWT** HS256 emitido por el backend (`customer_id`, 30 días). Se manda como
  `Authorization: Bearer <jwt>`; el interceptor de Dio lo toma de
  `ApiClient._sessionToken` (memoria) o, si no hay, de secure storage.
- **Recordar sesión** (default `true`): el JWT se persiste. Si el usuario lo
  desmarca, `AuthProvider` borra la copia persistida **después** de registrar el
  token FCM; la sesión sigue autenticada en memoria hasta cerrar la app, y al
  siguiente arranque cae en el login.
- **Arranque** (`SplashScreen._checkAuth`): JWT válido → Dashboard (y se refresca
  el token FCM); sin JWT pero `device_activated` → Login por identidad; nada →
  Activación.
- **Logout** (`AuthProvider.logout`): `DELETE /device_tokens?token=…` (invalida la
  fila en el backend), `FirebaseMessaging.deleteToken()`, limpia storage.
  `StorageService.clearAll()` **conserva** `remember_session` y `device_activated`,
  así que tras cerrar sesión el cliente vuelve a entrar **con su identidad**, no
  con el código de activación.
- Un 401 en cualquier request limpia la sesión (memoria + storage).
- No hay endpoint de logout en el backend; el JWT sigue siendo válido hasta expirar.

## Token FCM: ciclo de vida (leer antes de tocar auth)

Los recordatorios dependen 100% de que el cliente tenga un `DeviceToken` **activo**
en el backend; los jobs de recordatorio **saltan** al cliente si no lo tiene, sin
dejar rastro. Reglas:

1. `NotificationService` es singleton y se inicializa **una sola vez** en `main()`.
   `fcmToken` (cache) queda en `null` después de `deleteToken()` y nadie lo vuelve a
   llenar solo. Por eso **nunca** uses el cache para registrar: usa
   `await notificationService.refreshToken()`, que pide el token actual a Firebase
   (tras un `deleteToken()` Firebase emite uno nuevo).
2. Puntos que registran el token con `POST /device_tokens` (upsert; reactiva filas
   invalidadas y re-asigna el token al cliente actual):
   - después de `login()` (antes de borrar el JWT persistido si no se recuerda sesión),
   - al abrir la app con JWT (`_refreshDeviceToken`: `PUT /device_tokens/refresh`,
     y si el backend responde 404, `POST`),
   - cuando Firebase rota el token (`NotificationService.onTokenRefresh` →
     `AuthProvider._registerDeviceToken` si hay sesión).
   - La activación manda el token dentro de `POST /devices/activate`.
3. Bug histórico (sep 2026): logout → login en el mismo proceso registraba nada
   porque leía el cache nulo; el cliente dejaba de recibir recordatorios hasta un
   arranque en frío. Además el `DELETE` no existía en el backend. Ambos corregidos;
   la prueba manual es: entrar → cerrar sesión → volver a entrar **sin cerrar la
   app** → en consola Rails `customer.device_tokens.active.exists?` debe ser `true`.

## Endpoints usados (`api_client.dart`)

| Método | Ruta | Auth | Uso |
|---|---|---|---|
| POST | `/devices/activate` | no | activación (Dio aparte, sin interceptor) |
| POST | `/auth/login` | no | login por identidad |
| GET | `/auth/forgot_contract?phone=` | no | recuperar contrato por SMS |
| GET | `/settings` | no | config pública (Dio aparte) |
| GET | `/dashboard` | JWT | dashboard |
| GET | `/installments` | JWT | cuotas |
| POST | `/payments` | JWT | reportar pago (recibo base64) |
| GET | `/notifications`, POST `/notifications/mark_all_read` | JWT | notificaciones |
| POST | `/device_tokens` | JWT | registrar/reactivar token FCM |
| PUT | `/device_tokens/refresh?token=` | JWT | marcar uso |
| DELETE | `/device_tokens?token=` | JWT | invalidar en logout |

Los errores del backend llegan como `{ "error": "..." }`; `ApiClient` los convierte
en `ApiException(message, statusCode)`.

## Desarrollo y build

```bash
flutter pub get
flutter analyze
flutter test                      # solo test/widget_test.dart por ahora
flutter build apk --release       # build/app/outputs/flutter-apk/app-release.apk
```

- Toolchain que exige Flutter 3.47: Gradle 8.14.3 (`android/gradle/wrapper`),
  AGP 8.11.1 y Kotlin 2.2.20 (`android/settings.gradle.kts`), JDK 17. El APK
  release se firma con las llaves de **debug** (`build.gradle.kts` tiene el TODO).
- Distribución: APK directo a los clientes (no Play Store). Sube `version:` en
  `pubspec.yaml` en cada entrega.
- `NotificationService` no es inyectable (constructor privado, `late final
  FirebaseMessaging`), así que la lógica de tokens se verifica en dispositivo real
  con los `debugPrint` de `AuthProvider`/`ApiClient`, no con tests unitarios.
- `main.dart` imprime el token FCM y lo guarda en `fcm_token.txt` (documentos de la
  app) para pruebas; es solo de diagnóstico.

### Prueba de punta a punta contra el backend local (emulador)

```bash
# backend (puerto 3001 porque 3000 suele estar ocupado por otro dev server)
cd ../movicuotas-backend && bin/rails server -b 0.0.0.0 -p 3001 -d
# app: 10.0.2.2 es el host visto desde el emulador Android
flutter emulators --launch pixel_api34      # Pixel 6 / Android 14 / Google APIs
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3001/api/v1
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb logcat -s flutter:I                     # debugPrint de AuthProvider/ApiClient
```
En la BD de desarrollo hay dispositivos con código de activación
(`Device.where.not(activation_code: nil)`); el flujo verificado el 2026-09-14 fue
activar → cerrar sesión → login por identidad, comprobando en Rails que
`customer.device_tokens.active.exists?` vuelve a ser `true`.

## Diseño

- Color primario `#125282`; success `#10b981`, warning `#f59e0b`, error `#ef4444`
  (`utils/constants.dart`).
- Moneda: Lempiras, formato `L 1,234.56` (`utils/formatters.dart`); fechas en `es`.

---

**Última actualización**: 2026-09-14
