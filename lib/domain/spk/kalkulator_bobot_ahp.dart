class HasilEvaluasiAhp {
  final List<double> bobotTernormalisasi;
  final double lambdaMaks;
  final double consistencyIndex;
  final double consistencyRatio;
  final bool konsisten;

  const HasilEvaluasiAhp({
    required this.bobotTernormalisasi,
    required this.lambdaMaks,
    required this.consistencyIndex,
    required this.consistencyRatio,
    required this.konsisten,
  });
}

class KalkulatorBobotAhp {
  // Random Index (RI) Saaty untuk n = 1..6
  static const List<double> _randomIndex = [0.0, 0.0, 0.58, 0.90, 1.12, 1.24];

  /// Kriteria baku 4x4:
  /// [0] Kecepatan Keluar 7 Hari (Velocity)
  /// [1] Urgensi Stok Menipis / Minus
  /// [2] Margin Keuntungan (Kondisional jika HPP tersedia)
  /// [3] Frekuensi Anomali / Drift Stok
  static List<List<double>> matriksBawaan() => [
    [1.0, 1.0, 3.0, 2.0],
    [1.0, 1.0, 3.0, 2.0],
    [1 / 3, 1 / 3, 1.0, 0.5],
    [0.5, 0.5, 2.0, 1.0],
  ];

  HasilEvaluasiAhp hitungBobot(List<List<double>> matriks) {
    final n = matriks.length;
    if (n == 0) {
      return const HasilEvaluasiAhp(
        bobotTernormalisasi: [],
        lambdaMaks: 0.0,
        consistencyIndex: 0.0,
        consistencyRatio: 0.0,
        konsisten: true,
      );
    }

    // 1. Jumlah setiap kolom
    final jumlahKolom = List<double>.filled(n, 0.0);
    for (int j = 0; j < n; j++) {
      for (int i = 0; i < n; i++) {
        final nilai = matriks[i][j] <= 0 ? 1.0 : matriks[i][j];
        jumlahKolom[j] += nilai;
      }
    }

    // 2. Normalisasi matriks & rata-rata baris (vektor eigen prioritas)
    final bobot = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      double jumlahBaris = 0.0;
      for (int j = 0; j < n; j++) {
        final pembagi = jumlahKolom[j] == 0 ? 1.0 : jumlahKolom[j];
        jumlahBaris += (matriks[i][j] <= 0 ? 1.0 : matriks[i][j]) / pembagi;
      }
      bobot[i] = jumlahBaris / n;
    }

    // 3. Hitung Lambda Maks, CI, dan CR
    double lambdaMaks = 0.0;
    for (int i = 0; i < n; i++) {
      double jumlahKali = 0.0;
      for (int j = 0; j < n; j++) {
        jumlahKali += (matriks[i][j] <= 0 ? 1.0 : matriks[i][j]) * bobot[j];
      }
      if (bobot[i] > 0) {
        lambdaMaks += jumlahKali / bobot[i];
      }
    }
    lambdaMaks /= n;

    final ci = n > 1 ? (lambdaMaks - n) / (n - 1) : 0.0;
    final ri = (n - 1) < _randomIndex.length ? _randomIndex[n - 1] : 1.12;
    final cr = ri > 0 ? (ci / ri).clamp(0.0, 10.0) : 0.0;

    return HasilEvaluasiAhp(
      bobotTernormalisasi: bobot,
      lambdaMaks: lambdaMaks,
      consistencyIndex: ci,
      consistencyRatio: cr,
      konsisten: cr < 0.10,
    );
  }
}