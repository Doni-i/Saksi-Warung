import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entitas/barang.dart';
import '../../domain/entitas/kejadian_stok.dart';
import '../../domain/entitas/satuan_barang.dart';
import '../../domain/kasus_penggunaan/catat_stok_masuk.dart';
import '../../domain/kasus_penggunaan/rekonsiliasi_stok_opname.dart';
import '../../domain/repositori/kontrak_repositori_inventaris.dart';

class PengendaliInventaris extends ChangeNotifier {
  final KontrakRepositoriInventaris _repoInventaris;
  final CatatStokMasuk _catatStokMasuk;
  final RekonsiliasiStokOpname _rekonsiliasiOpname;
  static const _uuid = Uuid();

  PengendaliInventaris(
      this._repoInventaris,
      this._catatStokMasuk,
      this._rekonsiliasiOpname,
      );

  List<Barang> daftarBarang = [];
  List<KejadianStok> daftarAnomali = [];
  bool sedangMemuat = true;

  Future<void> muatUlangInventaris() async {
    sedangMemuat = true;
    notifyListeners();

    daftarBarang = await _repoInventaris.ambilSemuaBarangAktif();
    daftarAnomali = await _repoInventaris.ambilDaftarAnomaliTerbaru();

    sedangMemuat = false;
    notifyListeners();
  }

  List<SatuanBarang> _susunDaftarSatuan({
    required String idBarang,
    required String satuanDasar,
    required double hargaJualDasar,
    String? idSatuanDasarLama,
    String? namaSatuanGrosir,
    double? rasioSatuanGrosir,
    double? hargaJualGrosir,
    String? idSatuanGrosirLama,
  }) {
    final daftarSatuan = <SatuanBarang>[
      SatuanBarang(
        id: idSatuanDasarLama ?? _uuid.v4(),
        idBarang: idBarang,
        namaSatuan: satuanDasar,
        rasioKeDasar: 1.0,
        hargaJual: hargaJualDasar,
      ),
    ];

    if (namaSatuanGrosir != null &&
        namaSatuanGrosir.trim().isNotEmpty &&
        rasioSatuanGrosir != null &&
        rasioSatuanGrosir > 1 &&
        hargaJualGrosir != null) {
      daftarSatuan.add(
        SatuanBarang(
          id: idSatuanGrosirLama ?? _uuid.v4(),
          idBarang: idBarang,
          namaSatuan: namaSatuanGrosir.trim(),
          rasioKeDasar: rasioSatuanGrosir,
          hargaJual: hargaJualGrosir,
        ),
      );
    }

    return daftarSatuan;
  }

  Future<void> tambahBarangMaster({
    required String namaBarang,
    required String kategori,
    required String jenisBarang,
    required String satuanDasar,
    double? hppTerakhir,
    required double batasStokMinimum,
    required double hargaJualDasar,
    String? namaSatuanGrosir,
    double? rasioSatuanGrosir,
    double? hargaJualGrosir,
  }) async {
    final idBarang = _uuid.v4();
    final daftarSatuan = _susunDaftarSatuan(
      idBarang: idBarang,
      satuanDasar: satuanDasar,
      hargaJualDasar: hargaJualDasar,
      namaSatuanGrosir: namaSatuanGrosir,
      rasioSatuanGrosir: rasioSatuanGrosir,
      hargaJualGrosir: hargaJualGrosir,
    );

    final Barang entitas = jenisBarang == 'CURAH'
        ? BarangCurah(
      id: idBarang,
      namaBarang: namaBarang.trim(),
      kategori: kategori.trim().isEmpty ? 'Umum' : kategori.trim(),
      satuanDasar: satuanDasar,
      hppTerakhir: hppTerakhir,
      batasStokMinimum: batasStokMinimum,
      daftarSatuan: daftarSatuan,
    )
        : BarangKemasan(
      id: idBarang,
      namaBarang: namaBarang.trim(),
      kategori: kategori.trim().isEmpty ? 'Umum' : kategori.trim(),
      satuanDasar: satuanDasar,
      hppTerakhir: hppTerakhir,
      batasStokMinimum: batasStokMinimum,
      daftarSatuan: daftarSatuan,
    );

    await _repoInventaris.simpanBarangBaru(entitas, daftarSatuan);
    await muatUlangInventaris();
  }

  Future<void> perbaruiBarangMaster({
    required Barang barangLama,
    required String namaBarang,
    required String kategori,
    required String jenisBarang,
    required String satuanDasar,
    double? hppTerakhir,
    required double batasStokMinimum,
    required double hargaJualDasar,
    String? namaSatuanGrosir,
    double? rasioSatuanGrosir,
    double? hargaJualGrosir,
  }) async {
    final satuanDasarLama = barangLama.daftarSatuan
        .where((s) => s.namaSatuan.toLowerCase() == barangLama.satuanDasar.toLowerCase())
        .firstOrNull;
    final satuanGrosirLama = barangLama.daftarSatuan
        .where((s) => s.namaSatuan.toLowerCase() != barangLama.satuanDasar.toLowerCase())
        .firstOrNull;

    final daftarSatuan = _susunDaftarSatuan(
      idBarang: barangLama.id,
      satuanDasar: satuanDasar,
      hargaJualDasar: hargaJualDasar,
      idSatuanDasarLama: satuanDasarLama?.id,
      namaSatuanGrosir: namaSatuanGrosir,
      rasioSatuanGrosir: rasioSatuanGrosir,
      hargaJualGrosir: hargaJualGrosir,
      idSatuanGrosirLama: satuanGrosirLama?.id,
    );

    final Barang entitasBaru = jenisBarang == 'CURAH'
        ? BarangCurah(
      id: barangLama.id,
      kodeSku: barangLama.kodeSku,
      namaBarang: namaBarang.trim(),
      kategori: kategori.trim().isEmpty ? 'Umum' : kategori.trim(),
      satuanDasar: satuanDasar,
      hppTerakhir: hppTerakhir,
      batasStokMinimum: batasStokMinimum,
      stokTercatatDasar: barangLama.stokTercatatDasar,
      jumlahAnomaliTercatat: barangLama.jumlahAnomaliTercatat,
      aktif: barangLama.aktif,
      daftarSatuan: daftarSatuan,
    )
        : BarangKemasan(
      id: barangLama.id,
      kodeSku: barangLama.kodeSku,
      namaBarang: namaBarang.trim(),
      kategori: kategori.trim().isEmpty ? 'Umum' : kategori.trim(),
      satuanDasar: satuanDasar,
      hppTerakhir: hppTerakhir,
      batasStokMinimum: batasStokMinimum,
      stokTercatatDasar: barangLama.stokTercatatDasar,
      jumlahAnomaliTercatat: barangLama.jumlahAnomaliTercatat,
      aktif: barangLama.aktif,
      daftarSatuan: daftarSatuan,
    );

    await _repoInventaris.perbaruiMasterBarang(entitasBaru, daftarSatuan);
    await muatUlangInventaris();
  }

  Future<void> nonaktifkanBarang(String idBarang) async {
    await _repoInventaris.nonaktifkanBarang(idBarang);
    await muatUlangInventaris();
  }

  Future<({bool berhasil, String pesan})> catatKulakanAtauKonsumsi({
    required String idBarang,
    required String namaSatuan,
    required double kuantitas,
    double? totalHargaKulakan,
    bool konsumsiPribadi = false,
  }) async {
    final hasil = await _catatStokMasuk.jalankan(
      idBarang: idBarang,
      namaSatuan: namaSatuan,
      kuantitasMasuk: kuantitas,
      totalHargaKulakan: totalHargaKulakan,
      konsumsiPribadiKeluar: konsumsiPribadi,
    );
    if (hasil.berhasil) {
      await muatUlangInventaris();
    }
    return hasil;
  }

  Future<({bool berhasil, String pesan, double selisihDasar})> eksekusiOpname({
    required String idBarang,
    required double jumlahFisikDasar,
    String? catatan,
  }) async {
    final hasil = await _rekonsiliasiOpname.jalankan(
      idBarang: idBarang,
      jumlahFisikTerhitungDasar: jumlahFisikDasar,
      catatanOpname: catatan,
    );
    if (hasil.berhasil) {
      await muatUlangInventaris();
    }
    return hasil;
  }

  Future<List<KejadianStok>> ambilLogBarang(String idBarang) {
    return _repoInventaris.ambilRiwayatKejadianBarang(idBarang);
  }
}