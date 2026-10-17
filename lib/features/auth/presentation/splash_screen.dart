import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/l10n/labels.dart';
import '../../../core/theme/sw_tokens.dart';

/// Shown while the stored session is restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.sw;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsFill.truck, size: 56, color: t.lift),
            const SizedBox(height: Sp.md),
            Text(
              context.l10n.appTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Sp.xl),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
