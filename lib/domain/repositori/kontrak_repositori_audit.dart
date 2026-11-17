import '../entitas/entri_audit.dart';

abstract class KontrakRepositoriAudit {
  Future<List<RingkasanHarianAudit>> ambilRingkasanHarianAudit({int jumlahHari = 30});

  Future<int> hitungPerhatianMingguIni();

  Future<List<EntriJejakAudit>> ambilTimelineAudit({
    KategoriAudit kategori = KategoriAudit.semua,
    String? filterTanggalIso, // YYYY-MM-DD
    String? filterIdOperator,
    String? filterIdBarang,
    DateTime? sebelumWaktu,
    int batas = 50,
  });
}