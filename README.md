# Olivo (Flutter)

Invitaciones digitales de boda — migración multipuerto de [olivo](https://github.com/GerardoRosas-27/olivo) (TanStack/React) a Flutter.

Cada invitado recibe un enlace único (`/i/:token`) con código QR. Desde el panel se arma la boda, se envían invitaciones por WhatsApp, se recogen confirmaciones (RSVP) y se controla el acceso en la puerta (escáner).

**Repositorio:** https://github.com/GerardoRosas-27/olivo-flutter  
**Release móvil:** [v1.1.1-mobile](https://github.com/GerardoRosas-27/olivo-flutter/releases/tag/v1.1.1-mobile)

## Características

- Invitación personalizada por invitado (enlace + QR)
- **Enviar invitación**: imagen QR + mensaje de plantilla con enlace `/i/{token}` vía menú de compartir (elige WhatsApp). En **web** son dos pasos (imagen, luego texto)
- Confirmación de asistencia (RSVP sí/no) vía API pública
- Lista de invitados, grupos y aforo
- Escáner de puerta con cupo por invitado (`partySize` / `checkedInCount`); QR **vencido** al agotar cupo
- QR `/i/{token}` abre en cualquier teléfono; el cupo se controla solo en el Escáner de puerta
- Login admin **solo con correo** (sin contraseña), sesión local
- **Sync a Railway**: invitaciones públicas funcionan en **cualquier teléfono**
- Persistencia local: **SQLite** (móvil/escritorio) / SharedPreferences JSON (web)
- Seed demo: Ana & Mateo, tokens `demo-ana` y `demo-clone` (tras sync)

### QR = identidad

1. Abrir `https://…/i/{token}` → invitación digital personalizada (API pública).
2. Escanear el mismo QR en **Escáner** → check-in de puerta contra el cupo del host.

### API en el mismo proceso Express

| Método | Ruta | Uso |
|--------|------|-----|
| `PUT/POST` | `/api/host/sync` | Auth `Bearer <hostUserId>` — upsert boda + invitados |
| `GET` | `/api/public/invitation/:token` | Datos públicos de la invitación (o 404) |
| `POST` | `/api/public/rsvp` | `{ token, response, deviceId }` |
| `POST` | `/api/door/scan` | `{ token, hostUserId, deviceId }` → `checked_in` \| `full` \| `discarded` \| `missing` |
| `GET` | `/api/health` | Health |

Store: **`DATABASE_URL`** (Postgres) si está definida; si no, JSON en **`/data/olivo.json`** (o `./data`).

## Stack

Flutter 3.47+, Riverpod, go_router, sqflite, http, qr_flutter, mobile_scanner, Express + Docker en Railway.

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

API local:

```bash
cd server && npm i && node server.js
```

## Despliegue Railway (Docker)

1. Conecta el repo `GerardoRosas-27/olivo-flutter` en [Railway](https://railway.app).
2. Builder **DOCKERFILE** (`railway.toml`).
3. Multi-stage: Flutter web → `node:20-alpine` + Express + API + `fetch_apk.sh`.
4. **URL pública** en la app: **Cuenta →** `https://olivo-flutter-production.up.railway.app` (o tu dominio).
5. Tras el deploy: reabre el mismo `/i/{token}` (limpia flags viejos) o pulsa **Sincronizar invitaciones** (Cuenta / Invitados) para subir invitados y limpiar `cloneFlaggedAt` / `boundDeviceId` en Railway.

### Volumen (recomendado)

Monta un **Railway Volume** en `/data` para persistir invitaciones entre redeploys (sin Postgres).  
Opcional: añade un servicio Postgres y define `DATABASE_URL`.

Variables:

| Variable | Descripción |
|----------|-------------|
| `PORT` | Puerto (Railway lo inyecta) |
| `OLIVO_DATA_DIR` | Default `/data` |
| `DATABASE_URL` | Si existe, usa Postgres en lugar de JSON |

Descargas:

- `/downloads/olivo.apk`
- `/downloads/olivo-android.zip`
- `/downloads/olivo-ios.zip`

## Re-sync de invitados existentes

Los datos viejos solo viven en el teléfono/navegador. Para que el QR abra en otro dispositivo:

1. Abre la app (APK o web) con la cuenta host.
2. **Cuenta** → pega la URL de Railway → Guardar.
3. Pulsa **Sincronizar invitaciones** (o edita/envía un invitado — el sync va automático).
4. Abre `https://tu-railway/i/{token}` desde otro teléfono.

## Descargas móviles

### Android APK

```bash
flutter build apk --release
```

Release GitHub: tag `v1.1.1-mobile` con `Olivo.apk`, `Olivo-android.zip`, `Olivo-ios.zip`.

### iOS

No hay IPA firmado. El ZIP de iOS solo incluye `INSTALL_IOS.txt`. Hace falta Mac + Xcode + cuenta Apple Developer.

## Rutas

```
/                      → página del producto (marketing + descargas)
/app                   → mismo landing (si no hay sesión)
/login                 → auth solo correo
/admin                 → Resumen
/admin/boda            → detalles de la boda
/admin/invitados       → lista + Enviar + sync
/admin/escaner         → check-in puerta (API + fallback local)
/admin/cuenta          → sesión + URL pública + sync
/i/:token              → invitación digital (API primero)
```

## Licencia / origen

Producto portado desde el repo Olivo original de Gerardo Rosas.
