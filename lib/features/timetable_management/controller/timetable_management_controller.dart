import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../models/timeTable_model.dart';
import '../../../models/daftTimetable_model.dart';
import '../repository/timetable_management_repository.dart';

/// Real-time stream of all published active timetables
final realtimeTimetablesStreamProvider = StreamProvider.autoDispose<List<TimetableModel>>((ref) {
  final repo = ref.watch(timetableManagementRepositoryProvider);
  return repo.getRealtimeTimetables();
});

/// Real-time stream of draft timetables
final realtimeDraftTimetablesStreamProvider = StreamProvider.autoDispose<List<DraftTimetableModel>>((ref) {
  final repo = ref.watch(timetableManagementRepositoryProvider);
  return repo.getRealtimeDrafts();
});

/// State notifier for timetable management actions
class TimetableManagementController extends StateNotifier<AsyncValue<void>> {
  final TimetableManagementRepository _repository;

  TimetableManagementController(this._repository) : super(const AsyncValue.data(null));

  Future<bool> deleteTimetable({
    required String classNo,
    required String division,
    required String timetableName,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.softDeleteTimetable(
        classNo: classNo,
        division: division,
        timetableName: timetableName,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final timetableManagementControllerProvider =
    StateNotifierProvider<TimetableManagementController, AsyncValue<void>>((ref) {
  final repo = ref.watch(timetableManagementRepositoryProvider);
  return TimetableManagementController(repo);
});
