import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/boda/presentation/boda_screen.dart';
import '../../features/cuenta/presentation/cuenta_screen.dart';
import '../../features/escaner/presentation/escaner_screen.dart';
import '../../features/guest/presentation/guest_landing_screen.dart';
import '../../features/invitados/presentation/invitados_screen.dart';
import '../../features/resumen/presentation/admin_shell.dart';
import '../../features/resumen/presentation/resumen_screen.dart';
import '../data/providers.dart';

final _rootKey = GlobalKey<NavigatorState>();

bool _isPublicPath(String loc) {
  if (loc == '/login' || loc == '/') return true;
  if (loc.startsWith('/i/')) return true;
  return false;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/admin',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (auth.loading) return null;
      final loc = state.matchedLocation;
      final public = _isPublicPath(loc);
      final onLogin = loc == '/login';

      if (!auth.isAuthenticated) {
        if (public) return null;
        return '/login';
      }
      if (onLogin || loc == '/') return '/admin';
      // Old WhatsApp tab → Invitados (merged).
      if (loc == '/admin/whatsapp') return '/admin/invitados';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/admin',
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/i/:token',
        name: 'invitation',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => GuestLandingScreen(
          token: state.pathParameters['token']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdminShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                name: 'resumen',
                builder: (context, state) => const ResumenScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/boda',
                name: 'boda',
                builder: (context, state) => const BodaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/invitados',
                name: 'invitados',
                builder: (context, state) => const InvitadosScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/escaner',
                name: 'escaner',
                builder: (context, state) => const EscanerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/cuenta',
                name: 'cuenta',
                builder: (context, state) => const CuentaScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}
