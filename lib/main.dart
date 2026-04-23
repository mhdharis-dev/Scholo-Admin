import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/sidemenu/side_menu_bar.dart';
import 'firebase_options.dart';
import 'auth/screen/splash_Screen.dart';

/// 🧠 Provider to initialize Firebase
final firebaseProvider = FutureProvider<FirebaseApp>((ref) async {
  return await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
});

/// 🔐 Provider to manage login state (SharedPreferences)
final authStateProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final role = prefs.getString('role');
  return {'isLoggedIn': isLoggedIn, 'role': role};
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  static const Color primaryColor = Color(0xff1193D4);
  static const Color appbarColor = Colors.transparent;
  static const Color textColor = Colors.black;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseInit = ref.watch(firebaseProvider);
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Scholo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: Colors.grey.shade100,
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          secondary: primaryColor,
          surface: Colors.grey.shade100,
          background: Colors.grey.shade100,
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: textColor,
          onBackground: textColor,
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: appbarColor,
          foregroundColor: primaryColor,
          titleTextStyle: TextStyle(
            color: Color(0xff201e71),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
          titleLarge: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primaryColor),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade200,
          hintStyle: const TextStyle(fontSize: 16, color: Colors.black54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        useMaterial3: true,
      ),
      home: firebaseInit.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
        data: (_) {
          return authState.when(
            loading: () => const SplashScreen(),
            error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
            data: (auth) {
              final isLoggedIn = auth['isLoggedIn'] as bool;
              final role = auth['role'];

              if (isLoggedIn && role == 'admin') {
                return const AdminPanel();
              } else {
                return const SplashScreen();
              }
            },
          );
        },
      ),
    );
  }
}
