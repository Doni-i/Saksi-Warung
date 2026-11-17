enum KategoriAudit {
  semua,
  stokDanPenjualan,
  anomaliDanOpname,
  perubahanMaster,
  keamananKunci,
}

class RingkasanHarianAudit {
  final DateTime tanggal;
  final String kunciTanggal; // YYYY-MM-DD
  final int jumlahNormal;
  final int jumlahAnomali;
  final int jumlahEditMaster;

  const RingkasanHarianAudit({
    required this.tanggal,
    required this.kunciTanggal,
    required this.jumlahNormal,
    required this.jumlahAnomali,
    required this.jumlahEditMaster,
  });

  int get totalAktivitas => jumlahNormal + jumlahAnomali + jumlahEditMaster;
  int get totalPerhatian => jumlahAnomali + jumlahEditMaster;
}

class EntriJejakAudit {
  final String id;
  final KategoriAudit kategori;
  final String kodeAktivitas;
  final String judul;
  final String subjudul;
  final String? detailPerubahan;
  final String idOperator;
  final String namaOperator;
  final String? idBarangTerkait;
  final String? namaBarangTerkait;
  final double? stokSebelum;
  final double? deltaStok;
  final double? stokSesudah;
  final String? satuanDasar;
  final bool butuhPerhatian;
  final DateTime waktuKejadian;

  const EntriJejakAudit({
    required this.id,
    required this.kategori,
    required this.kodeAktivitas,
    required this.judul,
    required this.subjudul,
    this.detailPerubahan,
    required this.idOperator,
    required this.namaOperator,
    this.idBarangTerkait,
    this.namaBarangTerkait,
    this.stokSebelum,
    this.deltaStok,
    this.stokSesudah,
    this.satuanDasar,
    this.butuhPerhatian = false,
    required this.waktuKejadian,
  });
}