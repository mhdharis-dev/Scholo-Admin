import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../models/event_model.dart';
import '../repository/event_repository.dart';

/// Repository provider
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(FirebaseFirestore.instance);
});

/// Selected month provider (for calendar + quick links filter)
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Controller provider (same pattern as your teacherControllerProvider)
final eventControllerProvider =
StateNotifierProvider<EventController, AsyncValue<List<EventModel>>>((ref) {
  final repo = ref.watch(eventRepositoryProvider);
  return EventController(repo);
});

class EventController extends StateNotifier<AsyncValue<List<EventModel>>> {
  final EventRepository _repo;

  EventController(this._repo) : super(const AsyncLoading()) {
    _listenToEvents();
  }

  void _listenToEvents() {
    _repo.getEventsStream().listen(
          (events) {
        state = AsyncData(events);
      },
      onError: (e, st) {
        state = AsyncError(e, st);
      },
    );
  }

  Future<void> saveEvent(EventModel event, {String? oldTitle}) async {
    try {
      await _repo.saveEvent(event, oldTitle: oldTitle);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> deleteEvent(String title) async {
    try {
      await _repo.deleteEvent(title);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
