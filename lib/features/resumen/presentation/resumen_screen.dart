import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/message.dart';

class ResumenScreen extends ConsumerWidget {
  const ResumenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weddingAsync = ref.watch(weddingProvider);
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(weddingProvider);
          ref.invalidate(statsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            weddingAsync.when(
              data: (w) {
                if (w == null) return const SizedBox.shrink();
                final couple = coupleNames(w);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          couple.isEmpty ? 'Tu boda' : couple,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (w.weddingDate != null)
                              formatWeddingDate(w.weddingDate),
                            if (w.venueName.isNotEmpty) w.venueName,
                          ].join(' · '),
                          style: const TextStyle(color: OlivoColors.muted),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 16),
            statsAsync.when(
              data: (s) {
                if (s == null) return const SizedBox.shrink();
                final tiles = [
                  ('Invitados', '${s.guests}', Icons.people_outline),
                  ('Enviados', '${s.sent}', Icons.send_outlined),
                  ('Vistos', '${s.viewed}', Icons.visibility_outlined),
                  ('Confirmados', '${s.confirmed}', Icons.check_circle_outline),
                  ('Declinados', '${s.declined}', Icons.cancel_outlined),
                  ('En puerta', '${s.checkedIn}', Icons.door_front_door_outlined),
                  ('Clones', '${s.clones}', Icons.link_off),
                  ('Aforo', '${s.expected}', Icons.groups_outlined),
                ];
                return GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    for (final t in tiles)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(t.$3, size: 20, color: OlivoColors.olive),
                              const Spacer(),
                              Text(t.$2,
                                  style: Theme.of(context).textTheme.headlineMedium),
                              Text(t.$1,
                                  style: const TextStyle(
                                      color: OlivoColors.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Prueba la invitación demo: /i/demo-ana',
              style: TextStyle(color: OlivoColors.subtle, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
