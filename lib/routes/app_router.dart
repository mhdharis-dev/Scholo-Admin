import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/sidemenu/side_menu_bar.dart';
import '../features/dashbord/screen/dashboard_screen.dart';
import '../auth/screen/loginPage.dart';
import '../auth/screen/splash_Screen.dart';
import '../features/teachers/screen/teacher_list.dart';
import '../features/students/screen/students_list.dart';
import '../features/events/screen/events_screen.dart';
import '../features/teacherView/class_dashbord/screen/classWiseTeacherView_screen.dart';
import '../features/trashbin/screen/trashBin_screen.dart';
import '../features/notifications/screen/notifications _Page.dart';

// Import newly routed detail and sub-pages
import '../features/teacherView/class_dashbord/screen/teacherViewDashbord.dart';
import '../features/teacherView/attendance/screen/attendance_page.dart';
import '../features/teacherView/students/screen/teacherScreenStudentList.dart';
import '../features/teacherView/timetable_otherFiles/screen/tableAndOtherFilesPage_Screen.dart';
import '../features/teacherView/mark/screen/folderPage_screen.dart';
import '../features/teacherView/report/screen/year_wise_report.dart';
import '../features/teacherView/fee/screen/fee_list.dart';
import '../features/teacherView/fee/screen/fee_collection.dart';

final router = GoRouter(
  initialLocation: '/splash',

  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('isLoggedIn') ?? false;
    final role = prefs.getString('role');

    final isAuthRoute =
        state.matchedLocation == '/login' || state.matchedLocation == '/splash';

    if (!loggedIn && !isAuthRoute) return '/login';

    if (loggedIn && state.matchedLocation == '/login') return '/admin/dashboard';

    if (loggedIn && role != 'admin' && !isAuthRoute) return '/login';

    return null;
  },

  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, __) => const SplashScreen(),
    ),

    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginPage(),
    ),

    /// 🔥 MAIN ADMIN SHELL
    ShellRoute(
      builder: (context, state, child) {
        return AdminPanel(child: child); // ⬅️ YOUR UI HERE
      },
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/admin/teachers',
          builder: (_, __) => const TeacherListScreen(),
        ),
        GoRoute(
          path: '/admin/students',
          builder: (_, __) => const StudentListScreen(),
        ),
        GoRoute(
          path: '/admin/events',
          builder: (_, __) => const EventsScreen(),
        ),
        GoRoute(
          path: '/admin/classrooms',
          builder: (_, __) => const ClassWiseTeacherViewScreen(),
          routes: [
            GoRoute(
              path: 'attendance/:teacherId',
              builder: (context, state) => AttendancePage(
                teacherId: state.pathParameters['teacherId']!,
              ),
            ),
            GoRoute(
              path: 'teacher-dashboard/:teacherId',
              builder: (context, state) => TeacherDashbordScreen(
                teacherId: state.pathParameters['teacherId']!,
              ),
              routes: [
                GoRoute(
                  path: 'student-list',
                  builder: (context, state) => TeacherScreenStudentList(
                    teacherId: state.pathParameters['teacherId']!,
                  ),
                ),
                GoRoute(
                  path: 'timetable/:classNo/:division',
                  builder: (context, state) => TableAndOtherFilePageScreen(
                    teacherId: state.pathParameters['teacherId']!,
                    classNo: int.parse(state.pathParameters['classNo']!),
                    division: state.pathParameters['division']!,
                  ),
                ),
                GoRoute(
                  path: 'marks',
                  builder: (context, state) => ExamFolderPageScreen(
                    teacherId: state.pathParameters['teacherId']!,
                  ),
                ),
                GoRoute(
                  path: 'class-report',
                  builder: (context, state) => YearWiseReportScreen(
                    teacherId: state.pathParameters['teacherId']!,
                  ),
                ),
                GoRoute(
                  path: 'fees',
                  builder: (context, state) => FeeListScreen(
                    teacherId: state.pathParameters['teacherId']!,
                  ),
                ),
                GoRoute(
                  path: 'fee-collection',
                  builder: (context, state) => FeeCollectionPage(
                    teacherId: state.pathParameters['teacherId']!,
                    description: state.uri.queryParameters['description'] ?? '',
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/admin/trash',
          builder: (_, __) => const RecycleBinPage(),
        ),
        GoRoute(
          path: '/admin/notifications',
          builder: (_, __) => const NotificationsPage(),
        ),
      ],
    ),
  ],
);