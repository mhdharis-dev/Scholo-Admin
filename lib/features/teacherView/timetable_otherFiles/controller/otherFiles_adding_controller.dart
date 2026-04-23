import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../repository/otherFiles_adding_repository.dart';

class OtherFilesAddingController
    extends StateNotifier<AsyncValue<void>> {

  final OtherFilesRepository repository;

  OtherFilesAddingController(this.repository)
      : super(const AsyncData(null));

  Future<void> uploadFile({
    required String teacherId,
    required String title,
    required String subtitle,
    required String filePath,
    required String fileName,
    required String division,
    required int classNo,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() =>
        repository.uploadFile(
          teacherId: teacherId,
          title: title,
          subtitle: subtitle,
          filePath: filePath,
          fileName: fileName,
          division: division,
          classNo: classNo,
        ));
  }
}

/// Updated Provider name to reflect the generic "Other Files" context
final otherFilesAddingControllerProvider =
StateNotifierProvider<OtherFilesAddingController, AsyncValue<void>>((ref) {
  final repo = ref.watch(otherFilesRepositoryProvider);
  return OtherFilesAddingController(repo);
});