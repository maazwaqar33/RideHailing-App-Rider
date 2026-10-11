import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mock/mock_ride_repository.dart';
import '../domain/ride_models.dart';
import '../domain/ride_repository.dart';

final mockRideRepositoryProvider = Provider<MockRideRepository>(
  (ref) => MockRideRepository(),
);

final rideRepositoryProvider = Provider<RideRepository>(
  (ref) => ref.watch(mockRideRepositoryProvider),
);

/// The rider's currently active ride, if any (GET rides, newest first, first non-terminal).
/// Used to resume tracking after an app restart and to explain a 409 conflict.
final activeRideProvider = FutureProvider.autoDispose<Ride?>((ref) async {
  final page = await ref.watch(rideRepositoryProvider).list(perPage: 10);
  for (final ride in page.rides) {
    if (ride.status.isActive) return ride;
  }
  return null;
});

/// Single ride (with timeline) for detail / receipt screens.
final rideDetailProvider = FutureProvider.autoDispose.family<Ride, int>((
  ref,
  id,
) {
  return ref.watch(rideRepositoryProvider).get(id);
});

/// Paginated ride history.
class RideHistoryState {
  const RideHistoryState({
    this.rides = const [],
    this.page = 0,
    this.hasMore = true,
    this.loading = false,
    this.error,
  });

  final List<Ride> rides;
  final int page;
  final bool hasMore;
  final bool loading;
  final Object? error;

  RideHistoryState copyWith({
    List<Ride>? rides,
    int? page,
    bool? hasMore,
    bool? loading,
    Object? error,
    bool clearError = false,
  }) => RideHistoryState(
    rides: rides ?? this.rides,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );
}

class RideHistoryController extends Notifier<RideHistoryState> {
  @override
  RideHistoryState build() => const RideHistoryState();

  /// Loads the first page (pull-to-refresh) when [refresh] is true, otherwise the next page.
  Future<void> load({bool refresh = false}) async {
    if (state.loading) return;
    if (!refresh && !state.hasMore) return;
    final nextPage = refresh ? 1 : state.page + 1;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await ref
          .read(rideRepositoryProvider)
          .list(page: nextPage);
      state = state.copyWith(
        rides: refresh ? result.rides : [...state.rides, ...result.rides],
        page: result.currentPage,
        hasMore: result.hasMore,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }
}

final rideHistoryProvider =
    NotifierProvider<RideHistoryController, RideHistoryState>(
      RideHistoryController.new,
    );

/// GET rides/{id}/timeline (append-only status history).
final rideTimelineProvider = FutureProvider.autoDispose
    .family<List<TimelineEntry>, int>((ref, id) {
      return ref.watch(rideRepositoryProvider).timeline(id);
    });
