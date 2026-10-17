import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../l10n/labels.dart';
import '../network/api_failure.dart';
import '../theme/sw_tokens.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.sw;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? PhosphorIconsRegular.tray, size: 40, color: t.text3),
            const SizedBox(height: Sp.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.text2),
            ),
          ],
        ),
      ),
    );
  }
}

class FailureView extends StatelessWidget {
  const FailureView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.sw;
    final l10n = context.l10n;
    final message = error is ApiFailure
        ? l10n.failure(error as ApiFailure)
        : l10n.errContract;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsRegular.cloudSlash, size: 40, color: t.danger),
            const SizedBox(height: Sp.md),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: Sp.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(PhosphorIconsRegular.arrowClockwise),
                label: Text(l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Explains why actions are hidden for the viewer role.
class ReadOnlyNote extends StatelessWidget {
  const ReadOnlyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.sw;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(PhosphorIconsRegular.lockSimple, size: 16, color: t.text3),
        const SizedBox(width: Sp.xs),
        Flexible(
          child: Text(
            context.l10n.readOnlyNote,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: t.text3),
          ),
        ),
      ],
    );
  }
}

/// The one confirmation dialog. Returns true only on an explicit confirm.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? body,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final l10n = context.l10n;
  final t = context.sw;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: t.stopFill,
                  foregroundColor: t.stopOn,
                )
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel ?? l10n.confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final t = context.sw;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? t.stopFill : null,
      ),
    );
}

/// Telemetry value pinned LTR with tabular figures.
class Telemetry extends StatelessWidget {
  const Telemetry(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textDirection: TextDirection.ltr,
    style: (style ?? DefaultTextStyle.of(context).style).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}
