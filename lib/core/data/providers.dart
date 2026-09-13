import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'repositories/olivo_repository.dart';

final olivoRepoProvider = Provider<OlivoRepository>((ref) => OlivoRepository());

class AuthState {
  const AuthState({this.user, this.loading = true});

  final SessionUser? user;
  final bool loading;

  bool get isAuthenticated => user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState()) {
    _load();
  }

  final OlivoRepository _repo;

  Future<void> _load() async {
    final session = await _repo.getSession();
    state = AuthState(user: session, loading: false);
  }

  Future<void> signIn(String email) async {
    final user = await _repo.signInEmail(email);
    state = AuthState(user: user, loading: false);
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState(user: null, loading: false);
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(olivoRepoProvider));
});

final weddingProvider = FutureProvider.autoDispose<Wedding?>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.user == null) return null;
  return ref.watch(olivoRepoProvider).ensureWedding(auth.user!.userId);
});

final guestsProvider = FutureProvider.autoDispose<List<Guest>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.user == null) return [];
  return ref.watch(olivoRepoProvider).listGuests(auth.user!.userId);
});

final statsProvider = FutureProvider.autoDispose<AdminStats?>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.user == null) return null;
  return ref.watch(olivoRepoProvider).adminStats(auth.user!.userId);
});

final scansProvider = FutureProvider.autoDispose<List<ScanEvent>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.user == null) return [];
  return ref.watch(olivoRepoProvider).listScanEvents(auth.user!.userId);
});

final publicBaseUrlProvider =
    FutureProvider.autoDispose<String>((ref) async {
  final stored = await ref.watch(olivoRepoProvider).getPublicBaseUrl();
  if (stored != null && stored.isNotEmpty) return stored;
  if (Uri.base.hasScheme &&
      (Uri.base.scheme == 'http' || Uri.base.scheme == 'https')) {
    final origin = '${Uri.base.scheme}://${Uri.base.host}'
        '${Uri.base.hasPort ? ':${Uri.base.port}' : ''}';
    return origin;
  }
  return 'http://localhost:8080';
});

final deviceLocalStatsProvider =
    FutureProvider.autoDispose<DeviceLocalStats>((ref) async {
  return ref.watch(olivoRepoProvider).deviceLocalStats();
});
