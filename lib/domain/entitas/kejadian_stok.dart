abstract final class JenisKejadianStok {
  static const String penjualanKeluar = 'PENJUALAN_KELUAR';
  static const String kulakanMasuk = 'KULAKAN_MASUK';
  static const String selisihOpname = 'SELISIH_OPNAME';
  static const String anomaliStokMinus = 'ANOMALI_STOK_MINUS';
  static const String konsumsiPribadi = 'KONSUMSI_PRIBADI';
}

class KejadianStok {
  final String id;
  final String idBarang;
  final String idOperator;
  final String? namaOperatorSaatItu;
  final String jenisKejadian;
  final double deltaSatuanDasar;
  final double? stokSebelum;
  final double? stokSesudah;
  final double? hppSaatKejadian;
  final String? idReferensi;
  final String? catatan;
  final DateTime waktuKejadian;

  const KejadianStok({
    required this.id,
    required this.idBarang,
    required this.idOperator,
    this.namaOperatorSaatItu,
    required this.jenisKejadian,
    required this.deltaSatuanDasar,
    this.stokSebelum,
    this.stokSesudah,
    this.hppSaatKejadian,
    this.idReferensi,
    this.catatan,
    required this.waktuKejadian,
  });

  bool get adalahAnomali =>
      jenisKejadian == JenisKejadianStok.anomaliStokMinus ||
          jenisKejadian == JenisKejadianStok.selisihOpname;

  Map<String, Object?> kePetaSql() => {
    'id': id,
    'id_barang': idBarang,
    'id_operator': idOperator,
    'nama_operator_saat_itu': namaOperatorSaatItu,
    'jenis_kejadian': jenisKejadian,
    'delta_satuan_dasar': deltaSatuanDasar,
    'stok_sebelum': stokSebelum,
    'stok_sesudah': stokSesudah,
    'hpp_saat_kejadian': hppSaatKejadian,
    'id_referensi': idReferensi,
    'catatan': catatan,
    'waktu_kejadian': waktuKejadian.toIso8601String(),
  };

  factory KejadianStok.dariPetaSql(Map<String, Object?> peta) => KejadianStok(
    id: peta['id'] as String,
    idBarang: peta['id_barang'] as String,
    idOperator: peta['id_operator'] as String,
    namaOperatorSaatItu: peta['nama_operator_saat_itu'] as String?,
    jenisKejadian: peta['jenis_kejadian'] as String,
    deltaSatuanDasar: (peta['delta_satuan_dasar'] as num).toDouble(),
    stokSebelum: (peta['stok_sebelum'] as num?)?.toDouble(),
    stokSesudah: (peta['stok_sesudah'] as num?)?.toDouble(),
    hppSaatKejadian: (peta['hpp_saat_kejadian'] as num?)?.toDouble(),
    idReferensi: peta['id_referensi'] as String?,
    catatan: peta['catatan'] as String?,
    waktuKejadian: DateTime.parse(peta['waktu_kejadian'] as String),
  );
}