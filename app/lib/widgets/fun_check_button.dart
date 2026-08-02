import 'dart:math';
import 'package:flutter/material.dart';

class FunCheckButton extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const FunCheckButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<FunCheckButton> createState() => _FunCheckButtonState();
}

class _FunCheckButtonState extends State<FunCheckButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _confettiController;
  late List<ConfettiParticle> _particles;
  bool _isHovering = false;

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

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _particles = ConfettiPainter.generateParticles();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _handleTap() {
    // 1. Play animation independently
    _scaleController.forward().then((_) => _scaleController.reverse());

    // 2. Toggle value immediately for responsiveness
    widget.onChanged(!widget.value);

    // 3. Confetti if checking
    if (!widget.value) {
      _confettiController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                foregroundPainter: ConfettiPainter(
                  animation: _confettiController,
                  colorScheme: Theme.of(context).colorScheme,
                  particles: _particles,
                ),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                    color: widget.value
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                  ),
                  child: widget.value
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimary,
                        )
                      : (_isHovering
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.5),
                              )
                            : null),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final Animation<double> animation;
  final ColorScheme colorScheme;
  final List<ConfettiParticle> particles;

  ConfettiPainter({
    required this.animation,
    required this.colorScheme,
    List<ConfettiParticle>? particles,
  }) : particles = particles ?? generateParticles(),
       super(repaint: animation);

  static List<ConfettiParticle> generateParticles() {
    final random = Random();
    return List.generate(
      20,
      (i) => ConfettiParticle(
        angle: random.nextDouble() * 2 * pi,
        speed: random.nextDouble() * 20 + 10,
        color: [
          Colors.red,
          Colors.blue,
          Colors.green,
          Colors.yellow,
          Colors.purple,
        ][random.nextInt(5)],
        offset: random.nextDouble() * 2 * pi,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (animation.value == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final progress = animation.value;

    for (final particle in particles) {
      final distance = particle.speed * progress * 3; // Distance from center
      final particleCenter =
          center +
          Offset(
            cos(particle.angle) * distance,
            sin(particle.angle) * distance,
          );

      final paint = Paint()
        ..color = particle.color.withValues(alpha: 1 - progress);

      canvas.save();
      canvas.translate(particleCenter.dx, particleCenter.dy);
      // Spin the particle
      canvas.rotate(particle.offset + progress * 2 * pi);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 4, height: 4),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) => true;
}

class ConfettiParticle {
  final double angle;
  final double speed;
  final Color color;
  final double offset;

  ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.offset,
  });
}
