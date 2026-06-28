import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/otherFiles_model.dart';
import '../../../../models/timeTable_model.dart'; // Import Timetable model
import '../repository/tableAndOtherFilesPag_repository.dart';

/// 🔥 Stream Provider for Other Files
final otherFilesListProvider =
StreamProvider.family<List<OtherFilesModel>, String>((ref, teacherId) {
  final repo = ref.watch(timetableAndOtherFilesPageRepositoryProvider);
  return repo.getOtherFiles(teacherId);
});

/// 🔥 Stream Provider for Timetables
final timetablesListProvider = StreamProvider.family<List<TimetableModel>, TimetableQueryParams>((ref, params) {
  final repo = ref.watch(timetableAndOtherFilesPageRepositoryProvider);
  return repo.getTimeTables(
      params.classNo,
      params.division,
      params.teacherId
  );
});

/// 🔥 Controller for Actions
class TimetableAndOtherFilesPageController {
  final Ref ref;
  TimetableAndOtherFilesPageController(this.ref);

  // --- Other Files Actions ---

  Future<void> deleteOtherFiles(String id) async {
    await ref.read(timetableAndOtherFilesPageRepositoryProvider).softDeleteOtherFiles(id);
  }

  Future<void> updateTitleOtherFiles(String id, String title) async {
    await ref.read(timetableAndOtherFilesPageRepositoryProvider)
        .updateTitleOtherFiles(id, title);
  }

  // --- Timetable Actions ---

  Future<void> deleteTimetable({
    required String classNo,
    required String division,
    required String timetableName,
  }) async {
    await ref
        .read(timetableAndOtherFilesPageRepositoryProvider)
        .softDeleteTimeTables(
          classNo: classNo,
          division: division,
          timetableName: timetableName,
        );
  }
}

final timetableAndOtherFilesPageControllerProvider =
Provider((ref) => TimetableAndOtherFilesPageController(ref));