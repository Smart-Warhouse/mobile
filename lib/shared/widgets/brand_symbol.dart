import 'package:flutter/material.dart';

/// SW·Fleet symbol from the approved brand kit (docs/brand/logo/symbol.svg, "Concept 01: Lane Route"):
/// the standard variant on light surfaces, the kit's reversed variant on dark ones. Decorative — the app name
/// is always shown next to it as text.
class BrandSymbol extends StatelessWidget {
  const BrandSymbol({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark ? 'assets/brand/symbol_dark.png' : 'assets/brand/symbol_light.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}
