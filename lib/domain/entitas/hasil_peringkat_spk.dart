class MetrikKandidatKulakan {
  final String idBarang;
  final String namaBarang;
  final String satuanDasar;
  final double stokTercatatDasar;
  final double batasStokMinimum;
  final double kecepatanKeluar7Hari;
  final double? marginPersen;
  final int frekuensiAnomali;

  const MetrikKandidatKulakan({
    required this.idBarang,
    required this.namaBarang,
    required this.satuanDasar,
    required this.stokTercatatDasar,
    required this.batasStokMinimum,
    required this.kecepatanKeluar7Hari,
    this.marginPersen,
    required this.frekuensiAnomali,
  });

  double get rasioUrgensiStok {
    final batasAman = batasStokMinimum <= 0 ? 1.0 : batasStokMinimum;
    if (stokTercatatDasar <= 0) return 2.0 + (stokTercatatDasar.abs() / batasAman);
    return (batasAman / stokTercatatDasar).clamp(0.0, 2.0);
  }
}

class HasilPeringkatSpk {
  final String idBarang;
  final String namaBarang;
  final String satuanDasar;
  final double stokTercatatDasar;
  final double skorPreferensiTopsis;
  final int peringkat;
  final String alasanUtama;

  const HasilPeringkatSpk({
    required this.idBarang,
    required this.namaBarang,
    required this.satuanDasar,
    required this.stokTercatatDasar,
    required this.skorPreferensiTopsis,
    required this.peringkat,
    required this.alasanUtama,
  });
}