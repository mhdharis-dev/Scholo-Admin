import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import '../../../../models/teacher_model.dart';
import '../repository/month_wise_report_repository.dart';

class MonthReportParams {
  final String teacherId;
  final String monthKey; // "2025-11"

  const MonthReportParams({
    required this.teacherId,
    required this.monthKey,
  });

  @override
  bool operator ==(Object other) =>
      other is MonthReportParams &&
          teacherId == other.teacherId &&
          monthKey == other.monthKey;

  @override
  int get hashCode => teacherId.hashCode ^ monthKey.hashCode;
}

class DayReportModel {
  final DateTime date;
  final Map<String, dynamic> data;

  DayReportModel({required this.date, required this.data});

  String get label => DateFormat('yyyy-MM-dd').format(date);
}

class MonthWiseReportState {
  final bool loading;
  final String? error;
  final TeacherModel? teacher;
  final List<DayReportModel> reports;

  const MonthWiseReportState({
    required this.loading,
    required this.reports,
    this.teacher,
    this.error,
  });

  factory MonthWiseReportState.initial() =>
      const MonthWiseReportState(loading: true, reports: []);

  MonthWiseReportState copyWith({
    bool? loading,
    String? error,
    TeacherModel? teacher,
    List<DayReportModel>? reports,
  }) {
    return MonthWiseReportState(
      loading: loading ?? this.loading,
      error: error,
      teacher: teacher ?? this.teacher,
      reports: reports ?? this.reports,
    );
  }
}

final monthWiseReportControllerProvider = StateNotifierProvider.autoDispose
    .family<MonthWiseReportController, MonthWiseReportState, MonthReportParams>(
      (ref, params) {
    final repo = ref.watch(monthWiseReportRepositoryProvider);
    return MonthWiseReportController(
      repo,
      params.teacherId,
      params.monthKey,
    );
  },
);

class MonthWiseReportController
    extends StateNotifier<MonthWiseReportState> {
  final MonthWiseReportRepository _repo;
  final String teacherId;
  final String monthKey;

  MonthWiseReportController(
      this._repo,
      this.teacherId,
      this.monthKey,
      ) : super(MonthWiseReportState.initial()) {
    load();
  }

  String get monthLabel {
    final p = monthKey.split('-');
    return DateFormat('MMMM yyyy')
        .format(DateTime(int.parse(p[0]), int.parse(p[1])));
  }

  Future<void> load() async {
    try {
      final teacher = await _repo.fetchTeacher(teacherId);
      final raw = await _repo.fetchMonthAttendance(
        teacherId: teacherId,
        monthKey: monthKey,
      );

      final reports = raw
          .map(
            (e) => DayReportModel(
          date: e['date'] as DateTime,
          data: Map<String, dynamic>.from(e['data']),
        ),
      )
          .toList();

      state = state.copyWith(
        loading: false,
        teacher: teacher,
        reports: reports,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Failed to load attendance',
      );
    }
  }

  void refresh() => load();
}
