import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entitas/akun_kasbon.dart';
import '../../domain/entitas/barang.dart';
import '../../domain/entitas/makro_transaksi.dart';
import '../../domain/kasus_penggunaan/eksekusi_transaksi_makro.dart';
import '../../domain/repositori/kontrak_repositori_inventaris.dart';
import '../../domain/repositori/kontrak_repositori_transaksi.dart';
import '../../inti/basis_data/pengelola_basis_data.dart';

class PengendaliTransaksi extends ChangeNotifier {
  final KontrakRepositoriInventaris _repoInventaris;
  final KontrakRepositoriTransaksi _repoTransaksi;
  final EksekusiTransaksiMakro _eksekusiTransaksi;
  static const _uuid = Uuid();

  PengendaliTransaksi(
      this._repoInventaris,
      this._repoTransaksi,
      this._eksekusiTransaksi,
      );

  List<MakroTransaksi> daftarMakro = [];
  List<Barang> daftarBarang = [];
  List<OperatorWarung> daftarOperator = [];
  OperatorWarung? operatorAktif;
  List<AkunKasbon> daftarPelangganKasbon = [];
  double omzetHariIni = 0.0;
  bool fiturKasbonAktif = true;
  bool sedangMemuat = true;

  Barang? cariBarangUntukMakro(String idBarang) {
    for (final b in daftarBarang) {
      if (b.id == idBarang) return b;
    }
    return null;
  }

  Future<void> muatUlangData() async {
    sedangMemuat = true;
    notifyListeners();

    final db = await PengelolaBasisData.instansi.basisData;
    final settingKasbon = await db.query(
      'pengaturan_sistem',
      where: 'kunci = ?',
      whereArgs: ['fitur_kasbon_aktif'],
    );
    fiturKasbonAktif = settingKasbon.isEmpty || settingKasbon.first['nilai'] == 'true';

    daftarMakro = await _repoTransaksi.ambilSemuaMakro();
    daftarBarang = await _repoInventaris.ambilSemuaBarangAktif();
    daftarOperator = await _repoTransaksi.ambilDaftarOperator();
    operatorAktif = await _repoTransaksi.ambilOperatorAktif();
    daftarPelangganKasbon = await _repoTransaksi.ambilDaftarPelangganKasbon();
    omzetHariIni = await _repoTransaksi.hitungTotalOmzetHariIni();

    sedangMemuat = false;
    notifyListeners();
  }

  Future<void> gantiOperator(String idOperator) async {
    await _repoTransaksi.gantiOperatorAktif(idOperator);
    await muatUlangData();
  }

  Future<void> tambahOperator(String nama) async {
    if (nama.trim().isEmpty) return;
    await _repoTransaksi.tambahOperatorBaru(nama);
    await muatUlangData();
  }

  Future<HasilEksekusiTransaksi> catatPenjualan({
    required String idBarang,
    required String namaSatuan,
    required double kuantitas,
    double? hargaSatuanOverride,
    required String metodeBayar,
    String? idPelangganKasbon,
    double nominalTunaiDibayar = 0.0,
    String? catatan,
  }) async {
    final hasil = await _eksekusiTransaksi.jalankan(
      idBarang: idBarang,
      namaSatuan: namaSatuan,
      kuantitas: kuantitas,
      hargaSatuanOverride: hargaSatuanOverride,
      metodeBayar: metodeBayar,
      idPelangganKasbon: idPelangganKasbon,
      nominalTunaiDibayar: nominalTunaiDibayar,
      catatanTambahan: catatan,
    );
    if (hasil.berhasil) {
      await muatUlangData();
    }
    return hasil;
  }

  Future<void> simpanAtauPerbaruiMakro({
    String? idMakro,
    required String labelTombol,
    required String idBarang,
    required String namaSatuan,
    required double kuantitasBawaan,
    required double hargaSatuanBawaan,
    int? urutanTampil,
  }) async {
    final indeksLama = idMakro == null
        ? -1
        : daftarMakro.indexWhere((element) => element.id == idMakro);

    final urutan = urutanTampil ??
        (indeksLama >= 0
            ? daftarMakro[indeksLama].urutanTampil
            : daftarMakro.length + 1);

    final makro = MakroTransaksi(
      id: idMakro ?? _uuid.v4(),
      labelTombol: labelTombol.trim(),
      idBarang: idBarang,
      namaSatuan: namaSatuan.trim(),
      kuantitasBawaan: kuantitasBawaan,
      hargaSatuanBawaan: hargaSatuanBawaan,
      urutanTampil: urutan,
    );
    await _repoTransaksi.simpanMakro(makro);
    await muatUlangData();
  }

  Future<void> geserUrutanMakro(int indeksLama, int indeksBaru) async {
    if (indeksLama < 0 ||
        indeksLama >= daftarMakro.length ||
        indeksBaru < 0 ||
        indeksBaru >= daftarMakro.length) {
      return;
    }
    final salinan = List<MakroTransaksi>.from(daftarMakro);
    final dipindah = salinan.removeAt(indeksLama);
    salinan.insert(indeksBaru, dipindah);

    for (int i = 0; i < salinan.length; i++) {
      await _repoTransaksi.simpanMakro(salinan[i].copyWith(urutanTampil: i + 1));
    }
    await muatUlangData();
  }

  Future<void> hapusMakro(String idMakro) async {
    await _repoTransaksi.hapusMakro(idMakro);
    await muatUlangData();
  }

  Future<void> tambahPelangganKasbon(String nama, double limitKredit) async {
    await _repoTransaksi.tambahPelangganKasbon(nama, limitKredit);
    await muatUlangData();
  }

  Future<void> bayarCicilanKasbon(String idPelanggan, double nominal) async {
    await _repoTransaksi.catatPembayaranKasbon(
      idPelanggan,
      nominal,
      'Pembayaran cicilan kasbon',
    );
    await muatUlangData();
  }

  Future<void> setelStatusFiturKasbon(bool aktif) async {
    final db = await PengelolaBasisData.instansi.basisData;
    await db.insert(
      'pengaturan_sistem',
      {'kunci': 'fitur_kasbon_aktif', 'nilai': aktif ? 'true' : 'false'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await muatUlangData();
  }
}