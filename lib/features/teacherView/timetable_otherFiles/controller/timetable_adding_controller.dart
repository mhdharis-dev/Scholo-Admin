import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../repository/timetable_adding_repository.dart';
import '../../../../models/timeTable_model.dart';
import '../../../../models/daftTimetable_model.dart';

class TimetableController extends StateNotifier<AsyncValue<void>> {
  final TimetableRepository _repository;

  TimetableController({required TimetableRepository repository})
      : _repository = repository,
        super(const AsyncData(null));

  Future<void> publishTimetable({
    required BuildContext context,
    required String classNo,
    required String division,
    required String timetableName,
    required TimetableModel model,
    String? currentDraftId,
    required VoidCallback onSuccess,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await _repository.publishTimetable(
        classNo: classNo,
        division: division,
        timetableName: timetableName,
        model: model,
      );
      if (currentDraftId != null) {
        await _repository.deleteDraft(currentDraftId);
      }
    });

    if (result.hasError) {
      state = AsyncError(result.error!, result.stackTrace!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${result.error}"), backgroundColor: Colors.red),
      );
    } else {
      state = const AsyncData(null);
      onSuccess();
    }
  }

  Future<String?> saveDraft({
    required BuildContext context,
    required DraftTimetableModel model,
    String? currentDraftId,
  }) async {
    state = const AsyncLoading();
    String? newId;

    final result = await AsyncValue.guard(() async {
      newId = await _repository.saveDraft(model, draftId: currentDraftId);
    });

    if (result.hasError) {
      state = AsyncError(result.error!, result.stackTrace!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Save failed: ${result.error}"), backgroundColor: Colors.red),
      );
      return null;
    } else {
      state = const AsyncData(null);
      return newId;
    }
  }
}

final timetableControllerProvider =
StateNotifierProvider<TimetableController, AsyncValue<void>>((ref) {
  return TimetableController(repository: ref.watch(timetableRepositoryProvider));
});