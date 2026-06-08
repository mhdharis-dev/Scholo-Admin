import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';


/// Tracks whether the page intro animation has completed.
final pageAnimationProvider = StateProvider<bool>((ref) => false);

// ─────────────────────────────────────────────
//  Main error page
// ─────────────────────────────────────────────
class SomethingWentWrongPage extends ConsumerStatefulWidget {
  const SomethingWentWrongPage({super.key});

  @override
  ConsumerState<SomethingWentWrongPage> createState() =>
      _SomethingWentWrongPageState();
}

class _SomethingWentWrongPageState
    extends ConsumerState<SomethingWentWrongPage>
    with TickerProviderStateMixin {
  // Fade-in controller for the whole page
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // Continuous float animation for the robot illustration
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  // Bounce animation for the red alert badge
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();

    // ── Fade-in ──────────────────────────────
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward().then((_) {
      ref.read(pageAnimationProvider.notifier).state = true;
    });

    // ── Floating robot ───────────────────────
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // ── Alert badge bounce ───────────────────
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticInOut),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _floatCtrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top navigation bar ──────────
              _TopNavBar(),

              // ── Main scrollable content ─────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // Robot illustration
                      _RobotIllustration(
                        floatAnim: _floatAnim,
                        bounceAnim: _bounceAnim,
                      ),

                      const SizedBox(height: 40),

                      // Headline
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Something went wrong',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                            height: 1.15,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Sub-text
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'The page you are looking for is currently '
                              'unavailable or has been moved to a new '
                              'learning path.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: const Color(0xFF6B7280),
                            height: 1.55,
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),

              // ── Footer ──────────────────────
              _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Top navigation bar
// ─────────────────────────────────────────────
class _TopNavBar extends StatefulWidget {
  @override
  State<_TopNavBar> createState() => _TopNavBarState();
}

class _TopNavBarState extends State<_TopNavBar> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  void _showTooltip() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      return;
    }

    final RenderBox renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismissible background
          GestureDetector(
            onTap: _hideTooltip,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            top: offset.dy + size.height + 10,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: _TooltipCard(
                onClose: _hideTooltip,
                arrowOffset: 0, // Will be handled by Positioned right
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideTooltip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          const Text(
            'Scholo',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A7BB0),
              letterSpacing: -0.3,
            ),
          ),

          // Help icon button
          Container(
            key: _buttonKey,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD1D5DB),
                width: 1.5,
              ),
            ),
            child: IconButton(
              onPressed: _showTooltip,
              icon: const Icon(
                Icons.help_outline_rounded,
                color: Color(0xFF6B7280),
                size: 20,
              ),
              padding: EdgeInsets.zero,
              splashRadius: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _TooltipCard extends StatelessWidget {
  final VoidCallback onClose;
  final double arrowOffset;

  const _TooltipCard({required this.onClose, this.arrowOffset = 0});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Arrow
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CustomPaint(
            size: const Size(18, 10),
            painter: _ArrowPainter(),
          ),
        ),
        // Content Card
        Container(
          width: 280,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon with gradient
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF64b6ed), Color(0xFF1D9BF0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This URL does not work on this platform (mobiles).',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2D3142),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Paginator dots (decoration)
                  Row(
                    children: [
                      _dot(true),
                    ],
                  ),
                  // Button
                  ElevatedButton(
                    onPressed: onClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D9BF0),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dot(bool active) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFF1D9BF0) : const Color(0xFFE2E8F0),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
//  Robot illustration with animated badges
// ─────────────────────────────────────────────
class _RobotIllustration extends StatelessWidget {
  const _RobotIllustration({
    required this.floatAnim,
    required this.bounceAnim,
  });

  final Animation<double> floatAnim;
  final Animation<double> bounceAnim;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Teal circular background ────────
          Container(
            width: 280,
            height: 280,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFF5BBFC8), Color(0xFF3A9DAA)],
                center: Alignment(-0.2, -0.2),
              ),
            ),
          ),

          // ── Floating robot body ─────────────
          AnimatedBuilder(
            animation: floatAnim,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, floatAnim.value),
              child: _RobotBody(),
            ),
          ),

          // ── Decorative orbs ─────────────────
          ..._buildOrbs(),

          // ── Red alert badge (top-right) ─────
          Positioned(
            top: 22,
            right: 10,
            child: AnimatedBuilder(
              animation: bounceAnim,
              builder: (_, __) => Transform.scale(
                scale: bounceAnim.value,
                child: _AlertBadge(),
              ),
            ),
          ),

          // ── Green puzzle badge (bottom-left) ─
          Positioned(
            bottom: 40,
            left: 20,
            child: _PuzzleBadge(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOrbs() {
    final orbs = [
      // (left, top, size, color, opacity)
      _OrbData(left: 38,  top: 80,  size: 14, color: 0xFF2980B9, opacity: 0.9),
      _OrbData(left: 20,  top: 130, size: 20, color: 0xFF1A6B9A, opacity: 1.0),
      _OrbData(left: 50,  top: 200, size: 10, color: 0xFF3498DB, opacity: 0.7),
      _OrbData(right: 40, top: 80,  size: 12, color: 0xFFD4A843, opacity: 0.85),
      _OrbData(right: 22, top: 140, size: 16, color: 0xFFE8C45A, opacity: 0.9),
      _OrbData(right: 55, top: 200, size: 22, color: 0xFFC9A230, opacity: 0.8),
      _OrbData(right: 35, top: 245, size: 10, color: 0xFF2980B9, opacity: 0.6),
    ];

    return orbs.map((o) {
      return Positioned(
        left: o.left,
        right: o.right,
        top: o.top,
        child: Container(
          width: o.size,
          height: o.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(o.color).withValues(alpha: o.opacity),
            boxShadow: [
              BoxShadow(
                color: Color(o.color).withValues(alpha: 0.35),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class _OrbData {
  final double? left;
  final double? right;
  final double top;
  final double size;
  final int color;
  final double opacity;
  const _OrbData({
    this.left,
    this.right,
    required this.top,
    required this.size,
    required this.color,
    required this.opacity,
  });
}

// ─────────────────────────────────────────────
//  Drawn robot body
// ─────────────────────────────────────────────
class _RobotBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 180,
      child: CustomPaint(painter: _RobotPainter()),
    );
  }
}

class _RobotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // ── Body (main sphere) ──────────────────
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFF5BCCD6), Color(0xFF2E8C97)],
        center: const Alignment(-0.3, -0.4),
      ).createShader(Rect.fromCircle(
        center: Offset(cx, size.height * 0.45),
        radius: 70,
      ));

    canvas.drawCircle(Offset(cx, size.height * 0.45), 70, bodyPaint);

    // ── Shadow below body ───────────────────
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.87),
        width: 80,
        height: 20,
      ),
      shadowPaint,
    );

    // ── Antenna stub ───────────────────────
    final antennaPaint = Paint()
      ..color = const Color(0xFF1E7A88)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx, size.height * 0.13),
      Offset(cx, size.height * 0.04),
      antennaPaint,
    );
    canvas.drawCircle(
      Offset(cx, size.height * 0.03),
      5,
      Paint()..color = const Color(0xFF1E7A88),
    );

    // ── Eyes ────────────────────────────────
    final eyeWhite = Paint()..color = Colors.white;
    final eyePupil = Paint()..color = const Color(0xFF1A1A2E);

    // Left eye
    canvas.drawCircle(Offset(cx - 22, size.height * 0.42), 16, eyeWhite);
    canvas.drawCircle(Offset(cx - 22, size.height * 0.42), 10, eyePupil);
    canvas.drawCircle(
      Offset(cx - 17, size.height * 0.40),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );

    // Right eye
    canvas.drawCircle(Offset(cx + 22, size.height * 0.42), 16, eyeWhite);
    canvas.drawCircle(Offset(cx + 22, size.height * 0.42), 10, eyePupil);
    canvas.drawCircle(
      Offset(cx + 27, size.height * 0.40),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );

    // ── Sad mouth ───────────────────────────
    final mouthPaint = Paint()
      ..color = const Color(0xFF1E7A88)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final mouthPath = Path()
      ..moveTo(cx - 14, size.height * 0.60)
      ..quadraticBezierTo(cx, size.height * 0.55, cx + 14, size.height * 0.60);
    canvas.drawPath(mouthPath, mouthPaint);

    // ── Ear nubs ────────────────────────────
    final earPaint = Paint()..color = const Color(0xFF2E8C97);
    canvas.drawCircle(Offset(cx - 70, size.height * 0.45), 8, earPaint);
    canvas.drawCircle(Offset(cx + 70, size.height * 0.45), 8, earPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────
//  Alert badge (red ! circle)
// ─────────────────────────────────────────────
class _AlertBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFFF4757),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4757).withValues(alpha: 0.40),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Puzzle badge (green square)
// ─────────────────────────────────────────────
class _PuzzleBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF2ECC71),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2ECC71).withValues(alpha: 0.40),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.extension_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Footer
// ─────────────────────────────────────────────
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          // Footer links
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FooterLink('Privacy Policy'),
              _footerDivider(),
              _FooterLink('Terms of Service'),
              _footerDivider(),
              _FooterLink('System Status'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '© 2024 Scholo Learning Systems. All rights reserved.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerDivider() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 8),
    child: Text('·', style: TextStyle(color: Color(0xFF9CA3AF))),
  );
}

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to corresponding screen
        debugPrint('Tapped: $label');
      },
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF9CA3AF),
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}