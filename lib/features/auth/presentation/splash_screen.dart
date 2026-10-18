import 'package:flutter/material.dart';

import '../../../core/l10n/labels.dart';
import '../../../core/theme/sw_tokens.dart';
import '../../../shared/widgets/brand_symbol.dart';

/// Shown while the stored session is restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandSymbol(size: 72),
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
