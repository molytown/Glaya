import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../shared/theme/colors.dart';

class SignupSelectionScreen extends StatefulWidget {
  const SignupSelectionScreen({super.key});

  @override
  State<SignupSelectionScreen> createState() => _SignupSelectionScreenState();
}

class _SignupSelectionScreenState extends State<SignupSelectionScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _expandCustomer() {
    print('Customer signup button pressed');
    context.push('/signup/customer');
  }

  void _expandProfessional() {
    print('Professional signup button pressed');
    context.push('/signup/professional');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Customer side (left - top-left triangle)
          Positioned.fill(
            child: ClipPath(
              clipper: _CustomerClipper(),
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/signup_customer.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF000000).withValues(alpha: 0.3),
                        Color(0xFF000000).withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(40, 120, 150, 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Book beauty services\nand discover professionals',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Customer Sign Up button (top-left position below text)
          Positioned(
            left: 40,
            top: 240,
            child: SizedBox(
              width: 140,
              height: 50,
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                child: InkWell(
                  onTap: () {
                    print('Customer signup button tapped');
                    _expandCustomer();
                  },
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF000000).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Professional side (right - bottom-right triangle)
          Positioned.fill(
            child: ClipPath(
              clipper: _ProfessionalClipper(),
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/signup_professional.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF000000).withValues(alpha: 0.3),
                        Color(0xFF000000).withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(150, 0, 40, 120),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Professional',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD4AF37),
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Join our community\nof beauty professionals',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFFD4AF37),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Professional Sign Up button (bottom-right position above text)
          Positioned(
            right: 60,
            bottom: 220,
            child: SizedBox(
              width: 140,
              height: 50,
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                child: InkWell(
                  onTap: () {
                    print('Professional signup button tapped');
                    _expandProfessional();
                  },
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF000000).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: 40,
            left: 20,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => context.go('/login'),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    // 45-degree diagonal line from top-left to bottom-right
    path.moveTo(0, 0);
    path.lineTo(size.width, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CustomerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Top-left triangle
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ProfessionalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Bottom-right triangle
    path.moveTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
