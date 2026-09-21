import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      context.go('/admin/dashboard');
    }
  }

  Future<void> _login() async {
    if (_formkey.currentState != null && !_formkey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and password'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final controller = ref.read(loginControllerProvider.notifier);
    final success = await controller.login(email, password);

    if (!mounted) return;

    if (success) {
      TextInput.finishAutofillContext();
      context.go('/admin/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid email or password'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 850;

    return Scaffold(
      body: Stack(
        children: [
          // Background decoration for small screens or main background
          Container(
            color: const Color(0xfff8fafc),
          ),
          if (!isLargeScreen) ...[
            // Subtle decorative background shapes for mobile/tablet
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xff1D9BF0).withOpacity(0.15),
                      const Color(0xff1D9BF0).withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xff1193D4).withOpacity(0.15),
                      const Color(0xff1193D4).withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ],
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: isLargeScreen
                    ? _buildLargeScreenLayout(size, state)
                    : _buildSmallScreenLayout(size, state),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Two-column layout for Web / Desktop / Tablets (large screens)
  Widget _buildLargeScreenLayout(Size size, dynamic state) {
    return Container(
      height: 600,
      constraints: const BoxConstraints(maxWidth: 1000),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left visual branding side
          Expanded(
            flex: 1,
            child: Container(
              height: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
                gradient: LinearGradient(
                  colors: [Color(0xff1193D4), Color(0xff1D9BF0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  // Abstract background pattern
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.1,
                      child: GridPaper(
                        color: Colors.white,
                        divisions: 1,
                        subdivisions: 1,
                        interval: 40,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -50,
                    left: -50,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // White-bounded transparent logo
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/imagesJpg/Scholo_LogoTransperent.png',
                            height: 80,
                            width: 80,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Scholo Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Manage your institution\'s marks, attendance, reports and administrative operations in one unified workspace.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right Form side
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 32),
              child: _buildForm(state),
            ),
          ),
        ],
      ),
    );
  }

  // Single-column layout for Mobile
  Widget _buildSmallScreenLayout(Size size, dynamic state) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/imagesJpg/Scholo_LogoTransperent.png',
                height: 70,
                width: 70,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome Back',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xff1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to Scholo Admin panel',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 32),
            _buildForm(state),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(dynamic state) {
    return Form(
      key: _formkey,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputLabel('Email Address'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _emailController,
              hint: 'name@school.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 20),
            _buildInputLabel('Password'),
            const SizedBox(height: 6),
            _buildPasswordField(),
            const SizedBox(height: 32),
            state is AsyncLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xff475569),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    Iterable<String>? autofillHints,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onFieldSubmitted: (_) => _login(),
      validator: (val) {
        final v = val?.trim() ?? '';
        if (v.isEmpty) return 'Email address is required';
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!emailRegex.hasMatch(v)) return 'Please enter a valid email address';
        return null;
      },
      style: const TextStyle(fontSize: 15, color: Color(0xff1E293B)),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xff94A3B8), size: 20),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xff94A3B8), fontSize: 15),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff1D9BF0), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _show,
      obscuringCharacter: "•",
      autofillHints: const [AutofillHints.password],
      onFieldSubmitted: (_) => _login(),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Password is required';
        return null;
      },
      style: const TextStyle(fontSize: 15, color: Color(0xff1E293B)),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xff94A3B8), size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: const Color(0xff94A3B8),
            size: 20,
          ),
          onPressed: () => setState(() => _show = !_show),
        ),
        hintText: '••••••••',
        hintStyle: const TextStyle(color: Color(0xff94A3B8), fontSize: 15),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff1D9BF0), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xff1193D4), Color(0xff1D9BF0)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff1D9BF0).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Sign In',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
