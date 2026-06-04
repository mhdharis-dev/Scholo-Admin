import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scholo_admin/core/constant/image_constant.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    // ✅ Start Animation Controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // ✅ Logo Scale Animation
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // ✅ Logo Fade Animation
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // ✅ Text Slide Animation
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Start animation
    _controller.forward();

    // Load user session
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool("isLoggedIn") ?? false;

    if (!isLoggedIn) {
      _goTo('/login');
      return;
    }

    final role = prefs.getString("role");
    if (role == "admin") {
      _goTo('/admin/dashboard');
    } else {
      _goTo('/login');
    }
  }

  void _goTo(String path) {
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        context.go(path);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // ✅ Animated Logo
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: Image.asset(
                 ImageConstant.logo, // <-- Put your Scholo logo here
                  height: 120,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ✅ Animated App Name
            SlideTransition(
              position: _textSlide,
              child: const Text(
                "Scholo",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),
            //
            // const SizedBox(height: 40),
            //
            // // ✅ Loading Indicator
            // const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
