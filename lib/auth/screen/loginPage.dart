// lib/features/auth/screen/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scholo_admin/core/constant/image_constant.dart';
import 'package:scholo_admin/features/sidemenu/side_menu_bar.dart';
import '../controller/login_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _show = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final role =
    await ref.read(loginControllerProvider.notifier).restoreSession();
    if (role == 'admin' && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminPanel()),
      );
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    final controller = ref.read(loginControllerProvider.notifier);
    final success = await controller.login(email, password);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminPanel()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid email or password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height,
            child: Row(
              children: [
                Expanded(flex: 2, child: Container(color: const Color(0xff1193D4))),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Form(
                      key: _formkey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🔹 Logo
                          CircleAvatar(
                            radius: 80,
                            backgroundColor: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Image.asset(
                                ImageConstant.logoWithText,
                                fit: BoxFit.contain,
                                height: 115,
                                width: 115,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            'Sign In',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 40),
                          _buildTextField(_emailController, 'Email Address'),
                          const SizedBox(height: 20),
                          _buildPasswordField(),
                          const SizedBox(height: 30),
                          state.isLoading
                              ? const CircularProgressIndicator()
                              : _buildLoginButtonLap(theme, colorScheme),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return SizedBox(
      width: 350,
      height: 50,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey.shade100,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return SizedBox(
      width: 350,
      height: 50,
      child: TextFormField(
        controller: _passwordController,
        obscureText: _show,
        obscuringCharacter: "•",
        decoration: InputDecoration(
          suffixIcon: IconButton(
            icon: Icon(
              _show ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () => setState(() => _show = !_show),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          hintText: 'Password',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildLoginButtonLap(ThemeData theme, ColorScheme colorScheme) {
    return ElevatedButton(
      onPressed: _login,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.primaryColor,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 6,
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Text('Login', style: TextStyle(fontSize: 14)),
      ),
    );
  }
}
