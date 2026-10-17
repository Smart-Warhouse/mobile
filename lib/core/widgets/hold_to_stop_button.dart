import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/sw_tokens.dart';

/// The «إيقاف الكل / STOP ALL» control (SF-11, UI-07).
///
/// Press and hold for [holdDuration] (1 s) to fire: a progress fill shows
/// the hold, a light haptic marks the start and a heavy one the firing.
/// Letting go early cancels. Raw pointer events are used (not a gesture
/// recognizer) so a gloved, slightly moving thumb does not cancel the hold.
class HoldToStopButton extends StatefulWidget {
  const HoldToStopButton({
    super.key,
    required this.label,
    required this.hint,
    required this.semanticsLabel,
    required this.onFire,
    this.enabled = true,
    this.onDisabledPress,
    this.busy = false,
    this.holdDuration = const Duration(seconds: 1),
    this.height = Sp.bigTapTarget,
  });

  final String label;
  final String hint;
  final String semanticsLabel;
  final VoidCallback onFire;
  final bool enabled;

  /// Called on a press while disabled, to explain why (viewer role).
  final VoidCallback? onDisabledPress;

  /// A request is in flight: show a spinner, keep the button armed.
  final bool busy;
  final Duration holdDuration;
  final double height;

  @override
  State<HoldToStopButton> createState() => _HoldToStopButtonState();
}

class _HoldToStopButtonState extends State<HoldToStopButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )..addStatusListener(_onStatus);

  int _pointers = 0;
  bool _fired = false;

  @override
  void didUpdateWidget(HoldToStopButton old) {
    super.didUpdateWidget(old);
    _hold.duration = widget.holdDuration;
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && !_fired) {
      _fired = true;
      HapticFeedback.heavyImpact();
      widget.onFire();
    }
  }

  void _down(PointerDownEvent _) {
    _pointers++;
    if (!widget.enabled) {
      if (_pointers == 1) widget.onDisabledPress?.call();
      return;
    }
    if (_pointers == 1) {
      _fired = false;
      HapticFeedback.selectionClick();
      _hold.forward(from: 0);
    }
  }

  void _up() {
    _pointers = (_pointers - 1).clamp(0, 10);
    if (_pointers > 0 || !widget.enabled) return;
    if (!_fired) {
      _hold.reverse();
    } else {
      _hold.value = 0;
    }
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sw;
    final fill = widget.enabled ? t.stopFill : t.surface2;
    final on = widget.enabled ? t.stopOn : t.text3;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticsLabel,
      // Screen readers cannot hold; a long-press action fires directly.
      onLongPress: widget.enabled ? widget.onFire : widget.onDisabledPress,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: _down,
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) => Container(
            key: const ValueKey('stop-all-button'),
            height: widget.height,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(Sp.radius),
              border: Border.all(color: t.danger, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Hold progress grows from the reading start edge.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: _hold.value,
                    heightFactor: 1,
                    child: ColoredBox(color: on.withValues(alpha: 0.28)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: Sp.lg,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      widget.busy
                          ? SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: on,
                              ),
                            )
                          : Icon(
                              PhosphorIconsFill.octagon,
                              color: on,
                              size: 28,
                            ),
                      const SizedBox(width: Sp.md),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: on,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                            ),
                            Text(
                              widget.hint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(color: on),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
