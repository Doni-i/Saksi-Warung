import 'package:flutter/foundation.dart';
import '../../domain/entitas/entri_audit.dart';
import '../../domain/repositori/kontrak_repositori_audit.dart';

class PengendaliAudit extends ChangeNotifier {
  final KontrakRepositoriAudit _repoAudit;

  PengendaliAudit(this._repoAudit);

  int rentangHariGrafik = 30;
  List<RingkasanHarianAudit> dataGrafikHarian = [];
  List<EntriJejakAudit> timelineAudit = [];
  int jumlahPerhatian7Hari = 0;

  KategoriAudit kategoriDipilih = KategoriAudit.semua;
  String? filterTanggalIso; // YYYY-MM-DD when user taps a bar on the chart
  String? filterIdOperator;
  String? filterIdBarang;

  bool sedangMemuat = false;
  bool sedangMemuatHalamanBerikut = false;
  bool masihAdaDataBerikut = true;

  Future<void> muatRingkasanAwal({String? idBarangAwal}) async {
    sedangMemuat = true;
    filterIdBarang = idBarangAwal;
    filterTanggalIso = null;
    notifyListeners();

    dataGrafikHarian = await _repoAudit.ambilRingkasanHarianAudit(
      jumlahHari: rentangHariGrafik,
    );
    jumlahPerhatian7Hari = await _repoAudit.hitungPerhatianMingguIni();

    timelineAudit = await _repoAudit.ambilTimelineAudit(
      kategori: kategoriDipilih,
      filterTanggalIso: filterTanggalIso,
      filterIdOperator: filterIdOperator,
      filterIdBarang: filterIdBarang,
      batas: 50,
    );
    masihAdaDataBerikut = timelineAudit.length >= 50;

    sedangMemuat = false;
    notifyListeners();
  }

  Future<void> ubahRentangGrafik(int hariBaru) async {
    if (rentangHariGrafik == hariBaru) return;
    rentangHariGrafik = hariBaru;
    dataGrafikHarian = await _repoAudit.ambilRingkasanHarianAudit(
      jumlahHari: rentangHariGrafik,
    );
    notifyListeners();
  }

  Future<void> pilihTanggalGrafik(String? kunciTanggalIso) async {
    filterTanggalIso = filterTanggalIso == kunciTanggalIso ? null : kunciTanggalIso;
    await _segarkanTimeline();
  }

  Future<void> ubahKategori(KategoriAudit kategori) async {
    kategoriDipilih = kategori;
    await _segarkanTimeline();
  }

  Future<void> ubahFilterOperator(String? idOperator) async {
    filterIdOperator = idOperator;
    await _segarkanTimeline();
  }

  Future<void> resetSemuaFilter() async {
    kategoriDipilih = KategoriAudit.semua;
    filterTanggalIso = null;
    filterIdOperator = null;
    filterIdBarang = null;
    await _segarkanTimeline();
  }

  Future<void> _segarkanTimeline() async {
    sedangMemuat = true;
    notifyListeners();

    timelineAudit = await _repoAudit.ambilTimelineAudit(
      kategori: kategoriDipilih,
      filterTanggalIso: filterTanggalIso,
      filterIdOperator: filterIdOperator,
      filterIdBarang: filterIdBarang,
      batas: 50,
    );
    masihAdaDataBerikut = timelineAudit.length >= 50;

    sedangMemuat = false;
    notifyListeners();
  }

  Future<void> muatHalamanBerikutnya() async {
    if (sedangMemuatHalamanBerikut || !masihAdaDataBerikut || timelineAudit.isEmpty) {
      return;
    }

    sedangMemuatHalamanBerikut = true;
    notifyListeners();

    final kursorWaktu = timelineAudit.last.waktuKejadian;
    final tambahan = await _repoAudit.ambilTimelineAudit(
      kategori: kategoriDipilih,
      filterTanggalIso: filterTanggalIso,
      filterIdOperator: filterIdOperator,
      filterIdBarang: filterIdBarang,
      sebelumWaktu: kursorWaktu,
      batas: 50,
    );

    timelineAudit.addAll(tambahan);
    masihAdaDataBerikut = tambahan.length >= 50;

    sedangMemuatHalamanBerikut = false;
    notifyListeners();
  }
}