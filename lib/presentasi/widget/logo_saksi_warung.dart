import 'package:flutter/material.dart';
import '../../inti/tema/tema_saksi_warung.dart';

class LogoSaksiWarung extends StatelessWidget {
  final double ukuran;

  const LogoSaksiWarung({super.key, this.ukuran = 36});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ukuran,
      height: ukuran,
      child: CustomPaint(
        painter: _PelukisLogoSaksiWarung(),
      ),
    );
  }
}

class _PelukisLogoSaksiWarung extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final catLatar = Paint()..color = TemaSaksiWarung.latarObsidian;
    final catBingkai = Paint()
      ..color = TemaSaksiWarung.aksenOranye
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08;
    final catOranye = Paint()
      ..color = TemaSaksiWarung.aksenOranye
      ..style = PaintingStyle.fill;
    final catPutih = Paint()
      ..color = TemaSaksiWarung.kanvasBersih
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.04, h * 0.04, w * 0.92, h * 0.92),
      Radius.circular(w * 0.18),
    );
    canvas.drawRRect(rrect, catLatar);
    canvas.drawRRect(rrect, catBingkai);

    // Atap lapak warung (trapesium atas)
    final atap = Path()
      ..moveTo(w * 0.22, h * 0.36)
      ..lineTo(w * 0.30, h * 0.22)
      ..lineTo(w * 0.70, h * 0.22)
      ..lineTo(w * 0.78, h * 0.36)
      ..close();
    canvas.drawPath(atap, catOranye);

    // Pilar timbangan / buku besar laci (3 batang simetris)
    canvas.drawRect(Rect.fromLTWH(w * 0.26, h * 0.44, w * 0.11, h * 0.32), catPutih);
    canvas.drawRect(Rect.fromLTWH(w * 0.445, h * 0.40, w * 0.11, h * 0.36), catOranye);
    canvas.drawRect(Rect.fromLTWH(w * 0.63, h * 0.44, w * 0.11, h * 0.32), catPutih);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}