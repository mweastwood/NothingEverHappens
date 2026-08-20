import 'package:flutter/material.dart';

/// A wrapper widget that smoothly animates items when their layout position
/// changes (e.g. shuffling across columns or sliding into new positions on reload/update).
class SmoothShuffleItem extends StatefulWidget {
  final String id;
  final Widget child;
  final Duration duration;
  final Curve curve;

  const SmoothShuffleItem({
    super.key,
    required this.id,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOutCubic,
  });

  /// Static position registry mapping item id to its last known position.
  static final Map<String, Offset> _positions = {};

  /// Clear all cached positions (useful for tests or full resets).
  static void clearPositions() {
    _positions.clear();
  }

  @override
  State<SmoothShuffleItem> createState() => _SmoothShuffleItemState();
}

class _SmoothShuffleItemState extends State<SmoothShuffleItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Offset _currentDelta = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentDelta = Offset.zero;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPosition());
  }

  @override
  void didUpdateWidget(SmoothShuffleItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPosition());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkPosition() {
    if (!mounted) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) return;

    final scrollable = Scrollable.maybeOf(context);
    final scrollableBox = scrollable?.context.findRenderObject() as RenderBox?;

    Offset currentPos;
    if (scrollable != null &&
        scrollableBox != null &&
        scrollableBox.attached &&
        scrollableBox.hasSize) {
      final viewportPos = renderBox.localToGlobal(
        Offset.zero,
        ancestor: scrollableBox,
      );
      final scrollOffset = scrollable.position.hasPixels
          ? scrollable.position.pixels
          : 0.0;
      final axis = scrollable.axisDirection;
      if (axis == AxisDirection.down || axis == AxisDirection.up) {
        currentPos = Offset(viewportPos.dx, viewportPos.dy + scrollOffset);
      } else {
        currentPos = Offset(viewportPos.dx + scrollOffset, viewportPos.dy);
      }
    } else {
      currentPos = renderBox.localToGlobal(Offset.zero);
    }

    final oldPos = SmoothShuffleItem._positions[widget.id];
    SmoothShuffleItem._positions[widget.id] = currentPos;

    if (oldPos != null) {
      final inFlightOffset = _controller.isAnimating
          ? Offset.lerp(_currentDelta, Offset.zero, _animation.value) ??
                Offset.zero
          : Offset.zero;
      final effectiveOldPos = oldPos + inFlightOffset;
      final dx = effectiveOldPos.dx - currentPos.dx;
      final dy = effectiveOldPos.dy - currentPos.dy;

      if (dx.abs() > 1.0 || dy.abs() > 1.0) {
        _currentDelta = Offset(dx, dy);
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isAnimating && _currentDelta != Offset.zero) {
          final currentOffset = Offset.lerp(
            _currentDelta,
            Offset.zero,
            _animation.value,
          )!;
          return Transform.translate(
            offset: currentOffset,
            child: widget.child,
          );
        }
        return widget.child;
      },
    );
  }
}
