import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/sw_tokens.dart';

/// On-screen joystick. Reports the knob deflection in [-1, 1] on both axes
/// (screen frame: +x right, +y down) and (0, 0) on release.
class Joystick extends StatefulWidget {
  const Joystick({
    super.key,
    required this.onChanged,
    required this.semanticsLabel,
    this.enabled = true,
    this.size = 200,
  });

  final void Function(double dx, double dy) onChanged;
  final String semanticsLabel;
  final bool enabled;
  final double size;

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  Offset _knob = Offset.zero;

  double get _radius => widget.size / 2;

  void _update(Offset local) {
    final c = Offset(_radius, _radius);
    var d = local - c;
    final max = _radius * 0.8;
    if (d.distance > max) d = d / d.distance * max;
    setState(() => _knob = d);
    widget.onChanged(d.dx / max, d.dy / max);
  }

  void _reset() {
    setState(() => _knob = Offset.zero);
    widget.onChanged(0, 0);
  }

  @override
  void didUpdateWidget(Joystick old) {
    super.didUpdateWidget(old);
    if (!widget.enabled && _knob != Offset.zero) {
      _knob = Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sw;
    final knobSize = widget.size * 0.36;
    return Semantics(
      label: widget.semanticsLabel,
      enabled: widget.enabled,
      child: GestureDetector(
        onPanDown: widget.enabled ? (d) => _update(d.localPosition) : null,
        onPanUpdate: widget.enabled ? (d) => _update(d.localPosition) : null,
        onPanEnd: widget.enabled ? (_) => _reset() : null,
        onPanCancel: widget.enabled ? _reset : null,
        child: SizedBox.square(
          dimension: widget.size,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.surface2,
                    border: Border.all(color: t.border, width: 2),
                  ),
                ),
              ),
              // Cross-hair.
              Center(
                child: Container(
                  width: 2,
                  height: widget.size * 0.7,
                  color: t.border,
                ),
              ),
              Center(
                child: Container(
                  height: 2,
                  width: widget.size * 0.7,
                  color: t.border,
                ),
              ),
              Positioned(
                left: _radius + _knob.dx - knobSize / 2,
                top: _radius + _knob.dy - knobSize / 2,
                child: Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.enabled ? t.accent : t.text3,
                    boxShadow: [
                      BoxShadow(
                        color: t.text.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: Offset(0, math.min(3, knobSize / 20)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
