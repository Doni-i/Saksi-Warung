import 'dart:math' as math;
import '../entitas/hasil_peringkat_spk.dart';
import 'strategi_pemeringkatan.dart';

class MesinPeringkatTopsis implements StrategiPemeringkatan {
  @override
  List<HasilPeringkatSpk> hitungPeringkat(
      List<MetrikKandidatKulakan> kandidat,
      List<double> bobotKriteria,
      ) {
    if (kandidat.isEmpty) return [];

    // Bobot default jika tidak valid: [Velocity, UrgensiStok, Margin, Anomali]
    final wRaw = bobotKriteria.length == 4
        ? List<double>.from(bobotKriteria)
        : [0.35, 0.35, 0.15, 0.15];

    // Cek ketersediaan HPP (Margin): jika semua null, netralkan bobot margin & redistribusi
    final adaMarginDiketahui = kandidat.any((k) => k.marginPersen != null);
    final marginTersedia = kandidat
        .where((k) => k.marginPersen != null)
        .map((k) => k.marginPersen!)
        .toList();
    final medianMargin = marginTersedia.isEmpty
        ? 0.0
        : (marginTersedia..sort())[marginTersedia.length ~/ 2];

    if (!adaMarginDiketahui) {
      wRaw[2] = 0.0;
    }

    final totalBobot = wRaw.fold(0.0, (a, b) => a + b);
    final w = totalBobot > 0
        ? wRaw.map((b) => b / totalBobot).toList()
        : [0.4, 0.4, 0.0, 0.2];

    final m = kandidat.length;
    const jumlahKriteria = 4;

    // 1. Matriks Keputusan X (seluruh kriteria bertipe BENEFIT setelah transformasi)
    final matriksX = List.generate(m, (i) {
      final item = kandidat[i];
      return <double>[
        math.max(0.0, item.kecepatanKeluar7Hari),
        math.max(0.0, item.rasioUrgensiStok),
        math.max(0.0, item.marginPersen ?? medianMargin),
        math.max(0.0, item.frekuensiAnomali.toDouble()),
      ];
    });

    // 2. Pembagi Normalisasi Vektor (aman terhadap kolom nol total)
    final pembagiKolom = List<double>.filled(jumlahKriteria, 0.0);
    for (int j = 0; j < jumlahKriteria; j++) {
      double jumlahKuadrat = 0.0;
      for (int i = 0; i < m; i++) {
        jumlahKuadrat += matriksX[i][j] * matriksX[i][j];
      }
      pembagiKolom[j] = jumlahKuadrat > 0 ? math.sqrt(jumlahKuadrat) : 1.0;
    }

    // 3. Matriks Ternormalisasi Terbobot Y
    final matriksY = List.generate(m, (i) {
      return List.generate(jumlahKriteria, (j) {
        return (matriksX[i][j] / pembagiKolom[j]) * w[j];
      });
    });

    // 4. Solusi Ideal Positif (A+) dan Negatif (A-)
    final idealPositif = List<double>.filled(jumlahKriteria, 0.0);
    final idealNegatif = List<double>.filled(jumlahKriteria, 0.0);

    for (int j = 0; j < jumlahKriteria; j++) {
      double maks = matriksY[0][j];
      double min = matriksY[0][j];
      for (int i = 1; i < m; i++) {
        if (matriksY[i][j] > maks) maks = matriksY[i][j];
        if (matriksY[i][j] < min) min = matriksY[i][j];
      }
      idealPositif[j] = maks;
      idealNegatif[j] = min;
    }

    // 5. Jarak Euclidean D+, D- dan Skor Preferensi C_i
    final daftarSkor = <({MetrikKandidatKulakan item, double skor})>[];
    for (int i = 0; i < m; i++) {
      double dPlusSq = 0.0;
      double dMinSq = 0.0;
      for (int j = 0; j < jumlahKriteria; j++) {
        dPlusSq += math.pow(matriksY[i][j] - idealPositif[j], 2);
        dMinSq += math.pow(matriksY[i][j] - idealNegatif[j], 2);
      }
      final dPlus = math.sqrt(dPlusSq);
      final dMin = math.sqrt(dMinSq);
      final penyebut = dPlus + dMin;
      final ci = penyebut > 0 ? (dMin / penyebut).clamp(0.0, 1.0) : 0.0;
      daftarSkor.add((item: kandidat[i], skor: ci));
    }

    daftarSkor.sort((a, b) => b.skor.compareTo(a.skor));

    return List.generate(daftarSkor.length, (idx) {
      final entri = daftarSkor[idx];
      return HasilPeringkatSpk(
        idBarang: entri.item.idBarang,
        namaBarang: entri.item.namaBarang,
        satuanDasar: entri.item.satuanDasar,
        stokTercatatDasar: entri.item.stokTercatatDasar,
        skorPreferensiTopsis: entri.skor,
        peringkat: idx + 1,
        alasanUtama: _susunAlasanRingkas(entri.item),
      );
    });
  }

  String _susunAlasanRingkas(MetrikKandidatKulakan k) {
    final bagian = <String>[];
    if (k.stokTercatatDasar < 0) {
      bagian.add('Stok minus (${k.stokTercatatDasar.toStringAsFixed(0)} ${k.satuanDasar})');
    } else if (k.stokTercatatDasar <= k.batasStokMinimum) {
      bagian.add('Stok menipis');
    }
    if (k.kecepatanKeluar7Hari > 0) {
      bagian.add('Keluar ${k.kecepatanKeluar7Hari.toStringAsFixed(0)}/7hr');
    }
    if (k.frekuensiAnomali > 0) {
      bagian.add('${k.frekuensiAnomali}x anomali');
    }
    if (k.marginPersen != null && k.marginPersen! > 0) {
      bagian.add('Margin ${k.marginPersen!.toStringAsFixed(0)}%');
    }
    return bagian.isEmpty ? 'Pantauan rutin' : bagian.join(' • ');
  }
}