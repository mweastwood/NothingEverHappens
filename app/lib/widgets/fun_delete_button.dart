import 'dart:math';
import 'package:flutter/material.dart';

class FunDeleteButton extends StatefulWidget {
  final VoidCallback onTap;

  const FunDeleteButton({
    super.key,
    required this.onTap,
  });

  @override
  State<FunDeleteButton> createState() => _FunDeleteButtonState();
}

class _FunDeleteButtonState extends State<FunDeleteButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _poofController;
  bool _isHovering = false;
  bool _poofed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _poofController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _poofController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_poofed) return;

    setState(() {
      _poofed = true;
    });

    // 1. Play scale animation
    _scaleController.forward().then((_) => _scaleController.reverse());

    // 2. Start poof animation
    _poofController.forward(from: 0.0);

    // 3. Trigger tap callback after the poof animation starts/finishes
    // Let's delay the actual delete action slightly to allow the poof to be visible
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        widget.onTap();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: CustomPaint(
                foregroundPainter: PoofPainter(
                  animation: _poofController,
                ),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: errorColor,
                      width: 2,
                    ),
                    color: _isHovering
                        ? errorColor.withValues(alpha: 0.1)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: _isHovering || _poofed
                        ? errorColor
                        : errorColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PoofPainter extends CustomPainter {
  final Animation<double> animation;
  final List<PoofParticle> particles = [];

  PoofPainter({required this.animation}) : super(repaint: animation) {
    final random = Random();
    // Generate 12 cloud particles for a satisfying "poof"
    for (int i = 0; i < 12; i++) {
      particles.add(
        PoofParticle(
          angle: random.nextDouble() * 2 * pi,
          speed: random.nextDouble() * 12 + 6,
          size: random.nextDouble() * 4 + 3,
          color: [
            Colors.grey[400]!,
            Colors.grey[300]!,
            Colors.grey[200]!,
            Colors.white.withValues(alpha: 0.8),
          ][random.nextInt(4)],
        ),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (animation.value == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final progress = animation.value;

    for (final particle in particles) {
      final distance = particle.speed * progress * 2.5;
      final particleCenter = center +
          Offset(
            cos(particle.angle) * distance,
            sin(particle.angle) * distance,
          );

      final paint = Paint()
        ..color = particle.color.withValues(
          alpha: (1 - progress).clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.fill;

      // Draw expanding and shrinking puffy cloud circles
      canvas.drawCircle(
        particleCenter,
        particle.size * (1 - progress * 0.4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(PoofPainter oldDelegate) => true;
}

class PoofParticle {
  final double angle;
  final double speed;
  final double size;
  final Color color;

  PoofParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}
