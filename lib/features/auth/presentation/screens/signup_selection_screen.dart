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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final scale = (width / 375).clamp(0.75, 1.15).toDouble();
          final fontSizeTitle = (28 * scale).clamp(20.0, 32.0);
          final fontSizeBody = (14 * scale).clamp(12.0, 16.0);
          final fontSizeButton = (16 * scale).clamp(14.0, 18.0);
          final buttonWidth = (140 * scale).clamp(120.0, 160.0);
          final buttonHeight = (50 * scale).clamp(44.0, 56.0);
          final sidePadding = (40 * scale).clamp(24.0, 48.0);
          final verticalSpacing = (16 * scale).clamp(12.0, 20.0);
          final customerTopPadding = (120 * scale).clamp(80.0, 150.0);
          final professionalBottomPadding = (120 * scale).clamp(80.0, 150.0);
          final backButtonSize = (44 * scale).clamp(36.0, 48.0);
          final iconSize = (24 * scale).clamp(20.0, 28.0);

          return Stack(
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
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          sidePadding,
                          customerTopPadding,
                          sidePadding * 3.75,
                          0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer',
                              style: TextStyle(
                                fontSize: fontSizeTitle,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                            SizedBox(height: verticalSpacing),
                            Text(
                              'Book beauty services\nand discover professionals',
                              style: TextStyle(
                                fontSize: fontSizeBody,
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                            SizedBox(height: verticalSpacing * 2),
                            SizedBox(
                              width: buttonWidth,
                              height: buttonHeight,
                              child: Material(
                                color: Colors.transparent,
                                elevation: 8,
                                child: InkWell(
                                  onTap: () {
                                    print('Customer signup button tapped');
                                    _expandCustomer();
                                  },
                                  borderRadius: BorderRadius.circular(buttonHeight / 2),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(buttonHeight / 2),
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF000000).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        fontSize: fontSizeButton,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF000000),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          sidePadding * 3.75,
                          0,
                          sidePadding,
                          professionalBottomPadding,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Professional',
                              style: TextStyle(
                                fontSize: fontSizeTitle,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFD4AF37),
                                letterSpacing: 2,
                              ),
                            ),
                            SizedBox(height: verticalSpacing),
                            Text(
                              'Join our community\nof beauty professionals',
                              style: TextStyle(
                                fontSize: fontSizeBody,
                                color: const Color(0xFFD4AF37),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.right,
                            ),
                            SizedBox(height: verticalSpacing * 2),
                            SizedBox(
                              width: buttonWidth,
                              height: buttonHeight,
                              child: Material(
                                color: Colors.transparent,
                                elevation: 8,
                                child: InkWell(
                                  onTap: () {
                                    print('Professional signup button tapped');
                                    _expandProfessional();
                                  },
                                  borderRadius: BorderRadius.circular(buttonHeight / 2),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4AF37),
                                      borderRadius: BorderRadius.circular(buttonHeight / 2),
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF000000).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        fontSize: fontSizeButton,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF000000),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                      width: backButtonSize,
                      height: backButtonSize,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: iconSize,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
