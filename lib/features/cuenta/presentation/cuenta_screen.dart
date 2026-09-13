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
  bool _syncing = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    super.dispose();
  }

  Future<void> _syncNow() async {
    final auth = ref.read(authProvider).user;
    if (auth == null) return;
    setState(() => _syncing = true);
    try {
      await ref.read(olivoRepoProvider).setPublicBaseUrl(_baseUrl.text);
      ref.invalidate(publicBaseUrlProvider);
      final ok = await ref.read(olivoRepoProvider).syncToServer(
            auth.userId,
            email: auth.email,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Boda e invitados sincronizados en Railway. Los QR /i/{token} ya funcionan en cualquier teléfono.'
                : 'No se pudo sincronizar. Revisa la URL pública y la red.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
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
              subtitle: Text(
                'Host ID: ${auth.user?.userId ?? '—'}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('URL pública (Railway)',
              style: Theme.of(context).textTheme.titleMedium),
          const FormGap(),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              hintText: 'https://olivo-flutter-production.up.railway.app',
              helperText:
                  'Base de enlaces /i/:token, WhatsApp y API de invitaciones',
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
          const FormGap(),
          FilledButton.tonalIcon(
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_syncing ? 'Sincronizando…' : 'Sincronizar invitaciones'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tras crear o editar invitados, pulsa sincronizar (o envía una '
            'invitación) para que el QR funcione en otro teléfono.',
            style: TextStyle(color: OlivoColors.muted, fontSize: 13),
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
                    'Local: SQLite (móvil) / SharedPreferences (web).\n'
                    'Servidor (Railway): JSON en volumen /data o Postgres si '
                    'hay DATABASE_URL. La API pública sirve /i/{token} y el '
                    'escáner de puerta con cupo.',
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
