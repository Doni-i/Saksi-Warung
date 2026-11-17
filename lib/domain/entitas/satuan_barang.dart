class SatuanBarang {
  final String id;
  final String idBarang;
  final String namaSatuan;
  final double rasioKeDasar;
  final double hargaJual;

  const SatuanBarang({
    required this.id,
    required this.idBarang,
    required this.namaSatuan,
    required this.rasioKeDasar,
    required this.hargaJual,
  });

  double konversiKeSatuanDasar(double kuantitas) => kuantitas * rasioKeDasar;

  Map<String, Object?> kePetaSql() => {
    'id': id,
    'id_barang': idBarang,
    'nama_satuan': namaSatuan,
    'rasio_ke_dasar': rasioKeDasar,
    'harga_jual': hargaJual,
  };

  factory SatuanBarang.dariPetaSql(Map<String, Object?> peta) => SatuanBarang(
    id: peta['id'] as String,
    idBarang: peta['id_barang'] as String,
    namaSatuan: peta['nama_satuan'] as String,
    rasioKeDasar: (peta['rasio_ke_dasar'] as num).toDouble(),
    hargaJual: (peta['harga_jual'] as num).toDouble(),
  );
}