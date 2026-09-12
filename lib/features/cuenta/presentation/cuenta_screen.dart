import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/form_gap.dart';

class CuentaScreen extends ConsumerStatefulWidget {
  const CuentaScreen({super.key});

  @override
  ConsumerState<CuentaScreen> createState() => _CuentaScreenState();
}

class _CuentaScreenState extends ConsumerState<CuentaScreen> {
  final _baseUrl = TextEditingController();
  bool _hydrated = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final originAsync = ref.watch(publicBaseUrlProvider);

    originAsync.whenData((v) {
      if (!_hydrated) {
        _baseUrl.text = v;
        _hydrated = true;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(auth.user?.email ?? '—'),
              subtitle: const Text('Login local solo con correo (sin contraseña)'),
            ),
          ),
          const SizedBox(height: 16),
          Text('URL pública (Railway)', style: Theme.of(context).textTheme.titleMedium),
          const FormGap(),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              hintText: 'https://tu-app.up.railway.app',
              helperText: 'Se usa en enlaces /i/:token y mensajes WhatsApp',
            ),
          ),
          const FormGap(),
          FilledButton(
            onPressed: () async {
              await ref.read(olivoRepoProvider).setPublicBaseUrl(_baseUrl.text);
              ref.invalidate(publicBaseUrlProvider);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL pública guardada')),
              );
            },
            child: const Text('Guardar URL'),
          ),
          const SizedBox(height: 24),
          Text('Descargas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'En Railway: /downloads/olivo.apk, olivo-android.zip, olivo-ios.zip',
            style: TextStyle(color: OlivoColors.muted, fontSize: 13),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                final base = _baseUrl.text.replaceAll(RegExp(r'/$'), '');
                launchUrl(Uri.parse('$base/downloads/olivo.apk'));
              },
              icon: const Icon(Icons.android),
              label: const Text('Descargar APK'),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Base de datos',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text(
                    'Hoy: SQLite local (móvil/escritorio) y SharedPreferences JSON en web. '
                    'Futuro: Postgres (Neon/Railway) para sesión multi-dispositivo y sync — '
                    'misma forma de tablas weddings/guests/scan_events/sessions.',
                    style: TextStyle(color: OlivoColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
