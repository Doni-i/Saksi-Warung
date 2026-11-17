class MakroTransaksi {
  final String id;
  final String labelTombol;
  final String idBarang;
  final String namaSatuan;
  final double kuantitasBawaan;
  final double hargaSatuanBawaan;
  final int urutanTampil;

  const MakroTransaksi({
    required this.id,
    required this.labelTombol,
    required this.idBarang,
    required this.namaSatuan,
    required this.kuantitasBawaan,
    required this.hargaSatuanBawaan,
    this.urutanTampil = 0,
  });

  double get totalNominalBawaan => kuantitasBawaan * hargaSatuanBawaan;

  MakroTransaksi copyWith({
    String? id,
    String? labelTombol,
    String? idBarang,
    String? namaSatuan,
    double? kuantitasBawaan,
    double? hargaSatuanBawaan,
    int? urutanTampil,
  }) {
    return MakroTransaksi(
      id: id ?? this.id,
      labelTombol: labelTombol ?? this.labelTombol,
      idBarang: idBarang ?? this.idBarang,
      namaSatuan: namaSatuan ?? this.namaSatuan,
      kuantitasBawaan: kuantitasBawaan ?? this.kuantitasBawaan,
      hargaSatuanBawaan: hargaSatuanBawaan ?? this.hargaSatuanBawaan,
      urutanTampil: urutanTampil ?? this.urutanTampil,
    );
  }

  Map<String, Object?> kePetaSql() => {
    'id': id,
    'label_tombol': labelTombol,
    'id_barang': idBarang,
    'nama_satuan': namaSatuan,
    'kuantitas_bawaan': kuantitasBawaan,
    'harga_satuan_bawaan': hargaSatuanBawaan,
    'urutan_tampil': urutanTampil,
  };

  factory MakroTransaksi.dariPetaSql(Map<String, Object?> peta) => MakroTransaksi(
    id: peta['id'] as String,
    labelTombol: peta['label_tombol'] as String,
    idBarang: peta['id_barang'] as String,
    namaSatuan: peta['nama_satuan'] as String,
    kuantitasBawaan: (peta['kuantitas_bawaan'] as num).toDouble(),
    hargaSatuanBawaan: (peta['harga_satuan_bawaan'] as num).toDouble(),
    urutanTampil: (peta['urutan_tampil'] as num?)?.toInt() ?? 0,
  );
}