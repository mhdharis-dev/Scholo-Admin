import 'package:go_router/go_router.dart';
import 'package:scholo_admin/features/teacherView/attendance/screen/attendance_page.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../core/layout/admin_shell.dart';
import '../features/dashbord/screen/dashboard_screen.dart';
import '../auth/screen/loginPage.dart';
import '../auth/screen/splash_Screen.dart';
import '../features/teachers/screen/teacher_list.dart';
import '../features/students/screen/students_list.dart';
import '../features/events/screen/events_screen.dart';
import '../features/teacherView/class_dashbord/screen/classWiseTeacherView_screen.dart';
import '../features/trashbin/screen/trashBin_screen.dart';

final router = GoRouter(
  initialLocation: '/splash',

  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('isLoggedIn') ?? false;
    final role = prefs.getString('role');

    final isAuthRoute =
        state.matchedLocation == '/login' || state.matchedLocation == '/splash';

    if (!loggedIn && !isAuthRoute) return '/login';

    if (loggedIn && isAuthRoute) return '/admin/dashboard';

    if (role != 'admin') return '/login';

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
        return AdminPanelLayout(child: child); // ⬅️ YOUR UI HERE
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
            /// 🔥 NESTED (Teacher View deep navigation)
            // GoRoute(
            //   path: 'overview',
            //   builder: (_, __) => const TeacherOverviewScreen(),
            // ),
            // GoRoute(
            //   path: 'attendance',
            //   builder: (_, __) => const AttendancePage(teacherId: teacherId),
            // ),
          ],
        ),
        GoRoute(
          path: '/admin/trash',
          builder: (_, __) => const RecycleBinPage(),
        ),
      ],
    ),
  ],
);