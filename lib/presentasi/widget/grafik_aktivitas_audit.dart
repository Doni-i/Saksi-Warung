import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/entitas/entri_audit.dart';
import '../../domain/entitas/kejadian_stok.dart';
import '../../inti/tema/tema_saksi_warung.dart';

class GrafikAktivitasAudit extends StatelessWidget {
  final List<RingkasanHarianAudit> dataHarian;
  final String? tanggalTerpilihIso;
  final ValueChanged<String?> onPilihTanggal;
  final bool modeGelap;

  const GrafikAktivitasAudit({
    super.key,
    required this.dataHarian,
    required this.tanggalTerpilihIso,
    required this.onPilihTanggal,
    required this.modeGelap,
  });

  @override
  Widget build(BuildContext context) {
    if (dataHarian.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(child: Text('Belum ada data grafik audit.')),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final lebar = constraints.maxWidth;
        const tinggi = 152.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final idx = ((details.localPosition.dx / lebar) * dataHarian.length)
                .floor()
                .clamp(0, dataHarian.length - 1);
            onPilihTanggal(dataHarian[idx].kunciTanggal);
          },
          child: SizedBox(
            width: lebar,
            height: tinggi,
            child: CustomPaint(
              painter: _PelukisGrafikBatangAudit(
                dataHarian: dataHarian,
                tanggalTerpilihIso: tanggalTerpilihIso,
                modeGelap: modeGelap,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PelukisGrafikBatangAudit extends CustomPainter {
  final List<RingkasanHarianAudit> dataHarian;
  final String? tanggalTerpilihIso;
  final bool modeGelap;

  _PelukisGrafikBatangAudit({
    required this.dataHarian,
    required this.tanggalTerpilihIso,
    required this.modeGelap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padAtas = 12.0;
    const padBawah = 22.0;
    final tinggiPlot = size.height - padAtas - padBawah;

    final maxTotal = math.max(
      1,
      dataHarian.fold<int>(0, (m, e) => math.max(m, e.totalAktivitas)),
    );

    final catGrid = Paint()
      ..color = modeGelap ? Colors.white12 : Colors.black12
      ..strokeWidth = 1;

    // 3 horizontal guide lines
    for (int g = 0; g <= 2; g++) {
      final y = padAtas + (tinggiPlot * (g / 2));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), catGrid);
    }

    final slotLebar = size.width / dataHarian.length;
    final batangLebar = math.max(2.0, slotLebar * 0.68);

    final catNormal = Paint()..color = TemaSaksiWarung.hijauAman.withValues(alpha: 0.85);
    final catEdit = Paint()..color = TemaSaksiWarung.aksenOranye;
    final catAnomali = Paint()..color = TemaSaksiWarung.merahPeringatan;
    final catSorot = Paint()
      ..color = (modeGelap ? Colors.white : TemaSaksiWarung.latarObsidian).withValues(alpha: 0.14);

    for (int i = 0; i < dataHarian.length; i++) {
      final item = dataHarian[i];
      final xTengah = (i + 0.5) * slotLebar;
      final kiri = xTengah - (batangLebar / 2);

      if (tanggalTerpilihIso == item.kunciTanggal) {
        canvas.drawRect(
          Rect.fromLTWH(i * slotLebar, 0, slotLebar, size.height - padBawah),
          catSorot,
        );
      }

      double dasarY = padAtas + tinggiPlot;

      void gambarSegmen(int nilai, Paint cat) {
        if (nilai <= 0) return;
        final h = math.max(3.0, (nilai / maxTotal) * tinggiPlot);
        final atas = math.max(padAtas, dasarY - h);
        canvas.drawRect(Rect.fromLTRB(kiri, atas, kiri + batangLebar, dasarY), cat);
        dasarY = atas;
      }

      // Stack bottom-to-top: normal -> master edits -> anomalies
      gambarSegmen(item.jumlahNormal, catNormal);
      gambarSegmen(item.jumlahEditMaster, catEdit);
      gambarSegmen(item.jumlahAnomali, catAnomali);
    }

    // Start, middle, end date labels
    final indeksLabel = <int>{0, dataHarian.length ~/ 2, dataHarian.length - 1};
    for (final idx in indeksLabel) {
      final item = dataHarian[idx];
      final label = '${item.tanggal.day}/${item.tanggal.month}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: modeGelap ? Colors.grey : Colors.black54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final x = ((idx + 0.5) * slotLebar - tp.width / 2)
          .clamp(0.0, math.max(0.0, size.width - tp.width))
          .toDouble();
      tp.paint(canvas, Offset(x, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _PelukisGrafikBatangAudit oldDelegate) {
    return oldDelegate.dataHarian != dataHarian ||
        oldDelegate.tanggalTerpilihIso != tanggalTerpilihIso ||
        oldDelegate.modeGelap != modeGelap;
  }
}

class GrafikSaldoKartuStok extends StatelessWidget {
  final List<KejadianStok> riwayatTerbaruKeLama;
  final bool modeGelap;

  const GrafikSaldoKartuStok({
    super.key,
    required this.riwayatTerbaruKeLama,
    required this.modeGelap,
  });

  @override
  Widget build(BuildContext context) {
    final titik = riwayatTerbaruKeLama
        .where((k) => k.stokSesudah != null)
        .toList()
        .reversed
        .toList();

    if (titik.length < 2) {
      return const SizedBox(
        height: 76,
        child: Center(
          child: Text(
            'Minimal 2 pergerakan stok untuk menampilkan kurva saldo.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      height: 92,
      width: double.infinity,
      child: CustomPaint(
        painter: _PelukisKurvaSaldo(titik: titik, modeGelap: modeGelap),
      ),
    );
  }
}

class _PelukisKurvaSaldo extends CustomPainter {
  final List<KejadianStok> titik;
  final bool modeGelap;

  _PelukisKurvaSaldo({required this.titik, required this.modeGelap});

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 10.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    final nilaiSaldo = titik.map((e) => e.stokSesudah!).toList();
    final minVal = nilaiSaldo.reduce(math.min);
    final maxVal = nilaiSaldo.reduce(math.max);
    final rentang = math.max(1.0, maxVal - minVal);

    double yUntuk(double v) => pad + h - (((v - minVal) / rentang) * h);

    if (minVal < 0 && maxVal > 0) {
      final yNol = yUntuk(0);
      canvas.drawLine(
        Offset(pad, yNol),
        Offset(size.width - pad, yNol),
        Paint()
          ..color = TemaSaksiWarung.merahPeringatan.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
    }

    final garis = Path();
    for (int i = 0; i < titik.length; i++) {
      final x = pad + (w * (i / (titik.length - 1)));
      final y = yUntuk(titik[i].stokSesudah!);
      if (i == 0) {
        garis.moveTo(x, y);
      } else {
        // Step-line transition
        garis.lineTo(x, yUntuk(titik[i - 1].stokSesudah!));
        garis.lineTo(x, y);
      }
    }

    canvas.drawPath(
      garis,
      Paint()
        ..color = TemaSaksiWarung.aksenOranye
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    for (int i = 0; i < titik.length; i++) {
      final k = titik[i];
      final x = pad + (w * (i / (titik.length - 1)));
      final y = yUntuk(k.stokSesudah!);
      final warnaTitik = k.adalahAnomali
          ? TemaSaksiWarung.merahPeringatan
          : (k.deltaSatuanDasar >= 0
          ? TemaSaksiWarung.hijauAman
          : (modeGelap ? Colors.white : TemaSaksiWarung.latarObsidian));
      canvas.drawCircle(Offset(x, y), k.adalahAnomali ? 4.0 : 2.8, Paint()..color = warnaTitik);
    }
  }

  @override
  bool shouldRepaint(covariant _PelukisKurvaSaldo oldDelegate) =>
      oldDelegate.titik != titik || oldDelegate.modeGelap != modeGelap;
}