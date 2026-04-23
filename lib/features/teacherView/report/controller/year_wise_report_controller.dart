import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../repository/year_wise_report_repository.dart';
import '../../../../models/teacher_model.dart';

/// Combined data for the screen: teacher + grouped attendance
class YearWiseData {
  final TeacherModel? teacher;
  final Map<String, List<Map<String, dynamic>>> groupedData;

  const YearWiseData({
    required this.teacher,
    required this.groupedData,
  });
}

/// Async state: YearWiseData for a given teacherId
final yearWiseReportControllerProvider =
StateNotifierProvider.family<YearWiseReportController,
    AsyncValue<YearWiseData>, String>((ref, teacherId) {
  final repo = ref.read(yearWiseReportRepositoryProvider);
  return YearWiseReportController(repo, teacherId);
});

/// Selected year for dropdown (global for simplicity)
final selectedYearProvider = StateProvider<String?>((ref) => null);

class YearWiseReportController
    extends StateNotifier<AsyncValue<YearWiseData>> {
  final YearWiseReportRepository _repository;
  final String teacherId;

  YearWiseReportController(this._repository, this.teacherId)
      : super(const AsyncValue.loading()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = const AsyncValue.loading();
    try {
      final teacher = await _repository.fetchTeacherById(teacherId);
      final grouped = await _repository.fetchYearWiseReport(teacherId);

      state = AsyncValue.data(
        YearWiseData(
          teacher: teacher,
          groupedData: grouped,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
