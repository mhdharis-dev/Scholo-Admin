import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../repository/exam_folder_repository.dart';

/// ===============================
/// Repository Provider
/// ===============================
final examFolderRepositoryProvider =
Provider((ref) => ExamFolderRepository(FirebaseFirestore.instance));

/// ===============================
/// TEMP EXAM STATE NOTIFIER
/// ===============================
final tempExamProvider =
StateNotifierProvider.family<TempExamController, List<String>, String>(
      (ref, teacherId) {
    final repo = ref.read(examFolderRepositoryProvider);
    return TempExamController(repo, teacherId);
  },
);

class TempExamController extends StateNotifier<List<String>> {
  final ExamFolderRepository repo;
  final String teacherId;

  TempExamController(this.repo, this.teacherId) : super([]) {
    load();
  }

  Future<void> load() async {
    state = await repo.loadTempExams(teacherId);
  }

  Future<void> add(String name) async {
    await repo.addTempExam(teacherId, name);
    await load();
  }

  Future<void> remove(String name) async {
    await repo.removeTempExam(teacherId, name);
    await load();
  }
}

/// ===============================
/// 🔥 FIREBASE STREAM PROVIDER (Like Timetable)
/// ===============================
final examFolderListProvider =
StreamProvider.family<List<QueryDocumentSnapshot>, String>((ref, teacherId) {
  final repo = ref.watch(examFolderRepositoryProvider);
  return repo.getFirebaseExams(teacherId);
});

/// 🔥 Exam name suggestions (like feeDescriptionsProvider)
final examNameSuggestionsProvider =
FutureProvider.family<List<String>, String>((ref, teacherId) {
  final repo = ref.read(examFolderRepositoryProvider);
  return repo.getExamNamesOnce(teacherId);
});