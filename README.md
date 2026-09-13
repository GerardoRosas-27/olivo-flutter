# Olivo (Flutter)

Invitaciones digitales de boda — migración multipuerto de [olivo](https://github.com/GerardoRosas-27/olivo) (TanStack/React) a Flutter.

Cada invitado recibe un enlace único (`/i/:token`) con código QR. Desde el panel se arma la boda, se envían invitaciones por WhatsApp, se recogen confirmaciones (RSVP) y se controla el acceso en la puerta (escáner).

**Repositorio:** https://github.com/GerardoRosas-27/olivo-flutter

## Características

- Invitación personalizada por invitado (enlace + QR)
- **Enviar invitación** (una acción): imagen QR + mensaje de plantilla con enlace `/i/{token}` vía menú de compartir (elige WhatsApp)
- Confirmación de asistencia (RSVP sí/no)
- Lista de invitados, grupos y aforo
- Escáner de puerta con cupo por invitado (`partySize` / `checkedInCount`); QR **vencido** al agotar cupo
- Detección de enlaces compartidos / clonados (device binding)
- Login admin **solo con correo** (sin contraseña), sesión local
- Secciones admin: **Resumen**, **Boda**, **Invitados** (CRUD + plantilla WhatsApp), **Escáner**, **Cuenta**
- Persistencia local: **SQLite** (móvil/escritorio) / SharedPreferences JSON (web)
- Seed demo: Ana & Mateo, tokens `demo-ana` y `demo-clone`

### Base de datos (hoy → futuro)

Hoy todo es **local** en el dispositivo/navegador. El esquema (weddings / guests / scan_events / sessions) está listo para migrar a **Postgres** (Neon o Railway) cuando quieras sync multi-dispositivo.

## Stack

Flutter 3.47+, Riverpod, go_router, sqflite, qr_flutter, mobile_scanner, Express + Docker en Railway (mismo patrón que [mochila-market](https://github.com/GerardoRosas-27/mochila-market) / naves-arcade).

## Cómo ejecutar

```bash
export PATH="/workspace/flutter-sdk/bin:$PATH"   # o tu Flutter SDK
git clone https://github.com/GerardoRosas-27/olivo-flutter.git
cd olivo-flutter
flutter pub get
flutter run                 # móvil / desktop
flutter run -d chrome       # web (URLs: /admin, /i/:token)
flutter build web --release --base-href /
```

Demo tras login: abre `/i/demo-ana`.

## Despliegue Railway (Docker)

Patrón idéntico a mochila-market:

1. Crea un proyecto en [Railway](https://railway.app) y **conecta este repo** (`GerardoRosas-27/olivo-flutter`).
2. Railway detecta `railway.toml` → builder **DOCKERFILE**.
3. El `Dockerfile` multi-stage:
   - build Flutter web (`ghcr.io/gmeligio/flutter-web:3.47.2`)
   - imagen final `node:20-alpine` + Express
   - `fetch_apk.sh` descarga el APK desde GitHub Releases
4. Healthcheck: `GET /`
5. Publica el servicio (Generate Domain).
6. En la app: **Cuenta → URL pública** = `https://tu-servicio.up.railway.app`

Variables: no hace falta `DATABASE_URL` (todo local). Opcional futuro: Postgres.

Descargas en el deploy:

- `/downloads/olivo.apk`
- `/downloads/olivo-android.zip`
- `/downloads/olivo-ios.zip`

## Descargas móviles

### Android APK

```bash
flutter build apk --release
```

Release GitHub: tag `v1.0.4-mobile` con `Olivo.apk`, `Olivo-android.zip`, `Olivo-ios.zip`.

### iOS

No hay IPA firmado en este release. El ZIP de iOS solo incluye `INSTALL_IOS.txt` (honesto). Para producir IPA hace falta Mac + Xcode + cuenta Apple Developer.

## Rutas

```
/                      → página del producto (marketing + descargas)
/app                   → mismo landing (si no hay sesión)
/login                 → auth solo correo
/admin                 → Resumen
/admin/boda            → detalles de la boda
/admin/invitados       → lista + Enviar invitación (QR imagen + plantilla)
/admin/escaner         → check-in puerta
/admin/cuenta          → sesión + URL pública (Railway)
/i/:token              → invitación digital personalizada del invitado
```

## Licencia / origen

Producto portado desde el repo Olivo original de Gerardo Rosas.
