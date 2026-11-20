import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';

class HowItWorksSection extends StatefulWidget {
  const HowItWorksSection({super.key});

  @override
  State<HowItWorksSection> createState() => _HowItWorksSectionState();
}

class _HowItWorksSectionState extends State<HowItWorksSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _activeStep = 0;

  final List<HowItWorksStep> _steps = const [
    HowItWorksStep(
      icon: Icons.content_cut,
      step: '1',
      title: 'Choose Service',
      subtitle: 'Pick the service\nyou need',
    ),
    HowItWorksStep(
      icon: Icons.person,
      step: '2',
      title: 'Select Pro',
      subtitle: 'Choose from verified\nprofessionals',
    ),
    HowItWorksStep(
      icon: Icons.payment,
      step: '3',
      title: 'Book & Pay',
      subtitle: 'Secure your booking\nin seconds',
    ),
    HowItWorksStep(
      icon: Icons.star,
      step: '4',
      title: 'Get Glayed ✨',
      subtitle: 'Enjoy your service\nand glow!',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _startAutoRotate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startAutoRotate() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 4500));
      if (mounted) {
        setState(() {
          _activeStep = (_activeStep + 1) % _steps.length;
        });
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How Glaya Works',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: _buildSteps(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSteps() {
    final List<Widget> widgets = [];
    for (int i = 0; i < _steps.length; i++) {
      widgets.add(_StepItem(
        step: _steps[i],
        isActive: i == _activeStep,
        animation: _controller,
      ));
      if (i < _steps.length - 1) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.chevron_right,
            size: 16,
            color: Color(0xFFD6006E),
          ),
        ));
      }
    }
    return widgets;
  }
}

class _StepItem extends StatelessWidget {
  final HowItWorksStep step;
  final bool isActive;
  final AnimationController animation;

  const _StepItem({
    required this.step,
    required this.isActive,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          _AnimatedStepIcon(
            icon: step.icon,
            isActive: isActive,
            animation: animation,
          ),
          const SizedBox(height: 8),
          Text(
            '${step.step}. ${step.title}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            step.subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF000000),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AnimatedStepIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final AnimationController animation;

  const _AnimatedStepIcon({
    required this.icon,
    required this.isActive,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isActive)
            RotationTransition(
              turns: animation,
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Color(0xFFD6006E),
                      Color(0xFFB5179E),
                      Color(0xFF7209B7),
                      Color(0xFFD6006E),
                    ],
                  ),
                ),
              ),
            ),
          Container(
            width: isActive ? 52 : 56,
            height: isActive ? 52 : 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GlayaColors.vibrantPink.withValues(alpha: 0.1),
              border: Border.all(
                color: GlayaColors.vibrantPink.withValues(alpha: 0.3),
                width: isActive ? 0 : 1.5,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: GlayaColors.berry,
            ),
          ),
        ],
      ),
    );
  }
}

class HowItWorksStep {
  final IconData icon;
  final String step;
  final String title;
  final String subtitle;

  const HowItWorksStep({
    required this.icon,
    required this.step,
    required this.title,
    required this.subtitle,
  });
}
