import 'package:flutter/material.dart';
import 'package:easy_sidemenu/easy_sidemenu.dart';
import 'package:go_router/go_router.dart';

class AdminPanelLayout extends StatefulWidget {
  final Widget child;
  const AdminPanelLayout({super.key, required this.child});

  @override
  State<AdminPanelLayout> createState() => _AdminPanelLayoutState();
}

class _AdminPanelLayoutState extends State<AdminPanelLayout> {
  final SideMenuController _controller = SideMenuController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            color: const Color(0xff1293d4),
            child: SideMenu(
              controller: _controller,
              items: [
                SideMenuItem(
                  title: 'Dashboard',
                  icon: const Icon(Icons.dashboard),
                  onTap: (i, _) => context.go('/admin/dashboard'),
                ),
                SideMenuItem(
                  title: 'Teacher',
                  icon: const Icon(Icons.group),
                  onTap: (i, _) => context.go('/admin/teacher'),
                ),
                SideMenuItem(
                  title: 'Student',
                  icon: const Icon(Icons.school),
                  onTap: (i, _) => context.go('/admin/student'),
                ),
                SideMenuItem(
                  title: 'Events',
                  icon: const Icon(Icons.event),
                  onTap: (i, _) => context.go('/admin/events'),
                ),
                SideMenuItem(
                  title: 'Teacher View',
                  icon: const Icon(Icons.co_present),
                  onTap: (i, _) => context.go('/admin/teacher-view'),
                ),
              ],
            ),
          ),

          // Main Area
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 60,
                  color: Colors.white,
                  child: Row(
                    children: const [
                      Icon(Icons.search),
                      Spacer(),
                      Icon(Icons.notifications),
                      SizedBox(width: 10),
                      CircleAvatar(child: Icon(Icons.person)),
                    ],
                  ),
                ),
                // Page content loaded here
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
