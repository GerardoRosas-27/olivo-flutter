import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/form_gap.dart';

/// Página pública del producto (sin token de invitado).
class ProductLandingScreen extends ConsumerWidget {
  const ProductLandingScreen({super.key});

  static const releaseTag = 'v1.0.5-mobile';
  static const _repo =
      'https://github.com/GerardoRosas-27/olivo-flutter/releases/download';

  Uri _asset(String name) => Uri.parse('$_repo/$releaseTag/$name');

  Future<void> _open(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(deviceLocalStatsProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 56),
            children: [
              Text(
                'Olivo',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: OlivoColors.fg,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Invitaciones digitales de boda',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: OlivoColors.olive,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Crea la página de tu boda, envía a cada invitado un enlace '
                'único con código QR, recoge confirmaciones (RSVP) y controla '
                'el aforo en la puerta con el escáner.',
                textAlign: TextAlign.center,
                style: TextStyle(color: OlivoColors.muted, height: 1.45),
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Para anfitriones',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const FormGap(height: 10),
                      _bullet('Panel: boda, invitados, plantilla y escáner'),
                      _bullet(
                        'Una acción «Enviar invitación»: QR (imagen) + mensaje con enlace',
                      ),
                      _bullet(
                        'Cada invitado abre /i/{token} con su nombre y cupo',
                      ),
                      _bullet(
                        'En la puerta el QR se descuenta del cupo; al agotarse, vencido',
                      ),
                      const FormGap(height: 16),
                      FilledButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Entrar al panel'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Descargas',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Desde GitHub Releases ($releaseTag)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: OlivoColors.muted,
                        ),
                      ),
                      const FormGap(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _open(_asset('Olivo.apk')),
                        icon: const Icon(Icons.android, size: 18),
                        label: const Text('Android — APK'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _open(_asset('Olivo-android.zip')),
                        icon: const Icon(Icons.folder_zip_outlined, size: 18),
                        label: const Text('Android — ZIP (APK + notas)'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _open(_asset('Olivo-web.zip')),
                        icon: const Icon(Icons.language, size: 18),
                        label: const Text('Web — build estático (ZIP)'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _open(_asset('Olivo-ios.zip')),
                        icon: const Icon(Icons.phone_iphone, size: 18),
                        label: const Text('iOS — notas de instalación'),
                      ),
                      const FormGap(height: 10),
                      const Text(
                        'iOS: no hay IPA firmado en este release. Hace falta '
                        'Mac + Xcode + cuenta Apple Developer para instalar en dispositivo.',
                        style: TextStyle(
                          fontSize: 12,
                          color: OlivoColors.subtle,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'En este dispositivo / demo',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Cifras locales (SQLite o almacenamiento del navegador). '
                        'No son estadísticas globales del servicio.',
                        style: TextStyle(
                          fontSize: 12,
                          color: OlivoColors.muted,
                          height: 1.35,
                        ),
                      ),
                      const FormGap(height: 14),
                      statsAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (e, _) => Text(
                          '$e',
                          style: const TextStyle(color: OlivoColors.danger),
                        ),
                        data: (s) => Row(
                          children: [
                            Expanded(
                              child: _statTile('Bodas', '${s.weddings}'),
                            ),
                            Expanded(
                              child: _statTile('Invitados', '${s.guests}'),
                            ),
                            Expanded(
                              child: _statTile('Usuarios', '${s.users}'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Si te compartieron un enlace /i/…, ábrelo directamente: '
                'esa es tu invitación personalizada.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: OlivoColors.subtle.withValues(alpha: 0.95),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('·  ', style: TextStyle(color: OlivoColors.olive)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: OlivoColors.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _statTile(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: OlivoColors.olive,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: OlivoColors.muted),
        ),
      ],
    );
  }
}
