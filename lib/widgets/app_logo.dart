import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/brand.dart';
import '../core/theme.dart';

/// Selo quadrado cobalto com o Z em estêncil.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/brand/selo.svg', width: size, height: size, semanticsLabel: AppBrand.fullName);
}

/// Nome do app com o "Z" em cobalto, como na logo principal.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 28, this.color = AppColors.text});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: AppBrand.word),
        const TextSpan(text: ' '),
        TextSpan(text: AppBrand.letter, style: const TextStyle(color: AppColors.cobaltLight)),
      ]),
      style: AppText.display(size: size, color: color),
    );
  }
}

/// Logo horizontal (selo + nome).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: size),
        SizedBox(width: size * 0.3),
        Wordmark(size: size * 0.5),
      ],
    );
  }
}
