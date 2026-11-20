import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/presentation/providers/auth_notifier.dart';
import '../../../shared/providers/location_provider.dart';
import '../../../shared/services/config_service.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/utils/responsive_helper.dart';
import 'seasonal_auth_background.dart';

class AuthSlideOut extends ConsumerStatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;

  const AuthSlideOut({
    super.key,
    required this.isOpen,
    required this.onClose,
  });

  @override
  ConsumerState<AuthSlideOut> createState() => _AuthSlideOutState();
}

class _AuthSlideOutState extends ConsumerState<AuthSlideOut>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isRegister = false;
  bool _isLoading = false;
  String _error = '';
  bool _showPassword = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    if (widget.isOpen) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AuthSlideOut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_isRegister && _nameController.text.trim().length < 2) {
      return 'Please enter your full name';
    }
    if (_phoneController.text.trim().isEmpty) {
      return 'Please enter your phone number';
    }
    if (_passwordController.text.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _error = '';
    });

    final validationError = _validate();
    if (validationError != null) {
      setState(() {
        _error = validationError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // For now, just close the slide-out and let the user navigate to login
      // In the future, this should handle actual auth logic
      if (mounted) {
        widget.onClose();
        // Small delay to let the slide-out close animation finish
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          context.push('/login');
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final width = isDesktop ? 420.0 : MediaQuery.of(context).size.width * 0.9;

    return Stack(
      children: [
        // Overlay
        AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  color: Color(0xFF000000).withValues(alpha: 0.45),
                ),
              ),
            );
          },
        ),
        // Slide-out panel
        AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            return Align(
              alignment: Alignment.centerRight,
              child: Transform.translate(
                offset: Offset(width * _slideAnimation.value, 0),
                child: Container(
                  width: width,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF000000).withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(-8, 0),
                      ),
                    ],
                  ),
                  child: SeasonalAuthBackground(
                    child: SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Close button
                            Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                onPressed: widget.onClose,
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.1),
                                  shape: const CircleBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Brand
                            Row(
                              children: [
                                Image.asset(
                                  'assets/logo.png',
                                  height: 40,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Glaya',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Title
                            Text(
                              _isRegister ? 'Create Account' : 'Welcome Back',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isRegister
                                  ? 'Join Glaya to book beauty services'
                                  : 'Sign in to continue',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Error message
                            if (_error.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  _error,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFFFCCCC),
                                  ),
                                ),
                              ),
                            // Name field (register only)
                            if (_isRegister) ...[
                              _buildTextField(
                                controller: _nameController,
                                label: 'Full Name',
                                icon: Icons.person_outline,
                                keyboardType: TextInputType.name,
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Phone field
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Phone Number',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            // Password field
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_outline,
                              obscureText: !_showPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                              ),
                            ),
                            // Referral code (register only)
                            if (_isRegister) ...[
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _referralController,
                                label: 'Referral Code (Optional)',
                                icon: Icons.card_giftcard_outlined,
                              ),
                            ],
                            const SizedBox(height: 24),
                            // Submit button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFE91E8C),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFE91E8C),
                                        ),
                                      )
                                    : Text(
                                        _isRegister
                                            ? 'Create Account'
                                            : 'Sign In',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Toggle register/login
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isRegister
                                      ? 'Already have an account?'
                                      : "Don't have an account?",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isRegister = !_isRegister;
                                      _error = '';
                                    });
                                  },
                                  child: Text(
                                    _isRegister ? 'Sign In' : 'Sign Up',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
          ),
          prefixIcon: Icon(icon, color: Colors.white70),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
