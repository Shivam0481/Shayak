import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/request_repository.dart';
import '../../domain/entities/rescue_request.dart';

// ─── Repository Providers ───────────────────────────────────────────────────

final authRepoProvider = Provider<AuthRepository>((ref) => AuthRepository());
final requestRepoProvider = Provider<RequestRepository>((ref) => RequestRepository());

// ─── Auth Providers ──────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepoProvider).authStateChanges;
});

final currentShayakUserProvider = FutureProvider<ShayakUser?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.watch(authRepoProvider).getCurrentUserDoc();
});

// ─── Location Provider ───────────────────────────────────────────────────────

final userLocationProvider = StateProvider<({double lat, double lng})?>(
  (ref) => null,
);

// ─── Requests Providers ──────────────────────────────────────────────────────

final nearbyRequestsProvider = StreamProvider<List<RescueRequest>>((ref) {
  final location = ref.watch(userLocationProvider);
  if (location == null) return const Stream.empty();
  return ref.watch(requestRepoProvider).watchNearbyRequests(
        lat: location.lat,
        lng: location.lng,
      );
});

final allRequestsProvider = StreamProvider<List<RescueRequest>>((ref) {
  return ref.watch(requestRepoProvider).watchAllRequests();
});

final allVolunteersProvider = StreamProvider<List<ShayakUser>>((ref) {
  return ref.watch(authRepoProvider).watchAllVolunteers();
});

final responderProvider = StreamProvider.family<ShayakUser?, String>((ref, uid) {
  return ref.watch(authRepoProvider).watchUser(uid);
});

final userRequestsProvider = StreamProvider<List<RescueRequest>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(requestRepoProvider).watchUserRequests(user.uid);
});

// ─── Volunteer Toggle ────────────────────────────────────────────────────────

class VolunteerNotifier extends StateNotifier<bool> {
  final AuthRepository _repo;
  final String _uid;

  VolunteerNotifier(this._repo, this._uid, bool initial) : super(initial);

  Future<void> toggle() async {
    final newVal = !state;
    state = newVal;
    await _repo.toggleAvailability(_uid, newVal);
  }
}

final volunteerToggleProvider =
    StateNotifierProvider<VolunteerNotifier, bool>((ref) {
  final userAsync = ref.watch(currentShayakUserProvider);
  final repo = ref.watch(authRepoProvider);
  final uid = ref.watch(authStateProvider).value?.uid ?? '';
  final initial = userAsync.value?.isAvailable ?? false;
  return VolunteerNotifier(repo, uid, initial);
});
