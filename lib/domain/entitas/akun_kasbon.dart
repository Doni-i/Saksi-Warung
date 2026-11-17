class AkunKasbon {
  final String id;
  final String nama;
  final double limitKredit;
  final double totalHutangAktif;

  const AkunKasbon({
    required this.id,
    required this.nama,
    required this.limitKredit,
    this.totalHutangAktif = 0.0,
  });

  bool get apakahMelebihiLimit => limitKredit > 0.0 && totalHutangAktif >= limitKredit;

  bool bolehTambahHutang(double nominalBaru) {
    if (limitKredit <= 0.0) return true;
    return (totalHutangAktif + nominalBaru) <= limitKredit;
  }

  factory AkunKasbon.dariPetaSql(Map<String, Object?> peta) => AkunKasbon(
    id: peta['id'] as String,
    nama: peta['nama'] as String,
    limitKredit: (peta['limit_kredit'] as num?)?.toDouble() ?? 0.0,
    totalHutangAktif: (peta['saldo_hutang'] as num?)?.toDouble() ?? 0.0,
  );
}

class OperatorWarung {
  final String id;
  final String namaPanggilan;
  final bool aktifSekarang;

  const OperatorWarung({
    required this.id,
    required this.namaPanggilan,
    required this.aktifSekarang,
  });

  factory OperatorWarung.dariPetaSql(Map<String, Object?> peta) => OperatorWarung(
    id: peta['id'] as String,
    namaPanggilan: peta['nama_panggilan'] as String,
    aktifSekarang: (peta['aktif_sekarang'] as num?)?.toInt() == 1,
  );
}