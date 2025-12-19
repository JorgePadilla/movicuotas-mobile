# MOVICUOTAS Mobile

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)
![License](https://img.shields.io/badge/License-Proprietary-red)

**Aplicación móvil de consulta para clientes del sistema MOVICUOTAS**

[Características](#características) • [Instalación](#instalación) • [Desarrollo](#desarrollo) • [Documentación](#documentación)

</div>

---

## Descripción

MOVICUOTAS Mobile es una aplicación Flutter simple y enfocada que permite a los clientes consultar información sobre sus créditos de dispositivos móviles de manera rápida y segura.

### ¿Qué hace la app?

- Ver información del usuario y contrato
- Consultar la próxima cuota a pagar
- Ver el saldo pendiente
- Revisar historial de pagos realizados

### ¿Qué NO hace la app?

Esta es una aplicación de **solo consulta**. No incluye:
- Pagos en línea
- Modificación de datos
- Notificaciones push complejas
- Gestión de préstamos
- MDM o funcionalidad offline avanzada

## Características

### Autenticación Simple
- Login con número de identidad + número de contrato
- Sesiones seguras basadas en cookies HTTP-only
- Sin necesidad de recordar contraseñas complejas

### Dashboard Intuitivo
- Vista clara de la información del cliente
- Cuota actual destacada con fecha de vencimiento
- Saldo pendiente actualizado
- Acceso rápido al historial

### Historial de Pagos
- Lista completa de pagos realizados
- Detalles de método de pago y recibos
- Fechas y montos formateados

## Instalación

### Prerrequisitos

- Flutter SDK 3.x o superior
- Dart SDK 3.x o superior
- Android Studio o VS Code con extensiones de Flutter
- Git

### Configuración del Entorno

1. Clonar el repositorio:
```bash
git clone https://github.com/tu-org/movicuotas-mobile.git
cd movicuotas-mobile
```

2. Instalar dependencias:
```bash
flutter pub get
```

3. Configurar la URL del backend:
```dart
// lib/services/api_client.dart
static const String baseUrl = 'https://api.movicuotas.com'; // Cambiar según entorno
```

4. Ejecutar la aplicación:
```bash
flutter run
```

## Desarrollo

### Estructura del Proyecto

```
lib/
├── main.dart                          # Entry point
├── models/                            # Modelos de datos
│   ├── customer.dart
│   ├── loan.dart
│   ├── installment.dart
│   └── payment.dart
├── screens/                           # Pantallas principales
│   ├── login_screen.dart
│   ├── dashboard_screen.dart
│   └── payment_history_screen.dart
├── services/                          # Servicios y API
│   └── api_client.dart
└── utils/                             # Utilidades y constantes
    ├── constants.dart
    └── formatters.dart
```

### Dependencias Principales

- **dio**: Cliente HTTP para consumir la API REST
- **dio_cookie_manager**: Manejo automático de cookies de sesión
- **cookie_jar**: Persistencia de cookies en disco
- **path_provider**: Acceso a directorios del sistema
- **intl**: Formateo de fechas y montos

### Ejecutar Tests

```bash
# Tests de widgets
flutter test

# Tests de integración
flutter test integration_test/
```

### Build para Producción

```bash
# APK de debug (para testing)
flutter build apk --debug

# APK de release (para producción)
flutter build apk --release

# El APK estará en:
# build/app/outputs/flutter-apk/app-release.apk
```

## API Backend

La aplicación consume una API REST construida con Rails 8. Endpoints principales:

- `POST /login` - Autenticación
- `GET /customers/me` - Información del cliente
- `GET /loans/active` - Préstamo activo
- `GET /installments/current` - Cuota actual
- `GET /payments/history` - Historial de pagos
- `POST /logout` - Cerrar sesión

Ver [CLAUDE.md](./CLAUDE.md) para detalles completos de la integración.

## Autenticación

La app usa sesiones Rails basadas en cookies HTTP-only en lugar de JWT:

**Ventajas:**
- Más simple (no hay que manejar tokens manualmente)
- Automático (CookieJar se encarga de todo)
- Seguro (cookies HTTP-only)
- Persistente (se guarda en disco automáticamente)

## Diseño y Estilo

### Paleta de Colores

- **Primario**: `#125282` (Azul oscuro - confianza y profesionalismo)
- **Success**: `#10b981` (Verde)
- **Warning**: `#f59e0b` (Naranja)
- **Error**: `#ef4444` (Rojo)

### Moneda

- Lempiras hondureños (L)
- Formato: `L 1,234.56`

## Documentación

- [CLAUDE.md](./CLAUDE.md) - Documentación técnica completa
  - Arquitectura del sistema
  - Modelos de datos detallados
  - Flujos de trabajo con código
  - Decisiones de diseño
  - Guías de implementación

## Seguridad

- Autenticación con sesiones Rails HTTP-only
- Cookies encriptadas y firmadas
- No se almacenan credenciales en el dispositivo
- Comunicación HTTPS obligatoria
- Timeout automático de sesión

## Soporte

Para reportar problemas o solicitar funcionalidades:

1. Crear un issue en el repositorio
2. Incluir pasos para reproducir (si es un bug)
3. Adjuntar screenshots si es relevante
4. Especificar versión de la app y dispositivo

## Roadmap

### Versión Actual (v1.0)
- Login con identidad + contrato
- Dashboard con cuota actual
- Historial de pagos

### Futuras Versiones
- Notificaciones de recordatorio de pago
- Modo oscuro
- Soporte para múltiples contratos
- Exportar historial a PDF

## Contribuir

Este es un proyecto privado. Para contribuir:

1. Crear un branch feature desde `main`
2. Realizar cambios siguiendo las guías de estilo
3. Escribir tests para funcionalidad nueva
4. Crear Pull Request con descripción clara

## Licencia

Propietario - MOVICUOTAS. Todos los derechos reservados.

---

**Desarrollado con** ❤️ **por el equipo MOVICUOTAS**

**Última actualización**: Diciembre 2024
