import 'package:uuid/uuid.dart';
import '../entitas/kejadian_stok.dart';
import '../repositori/kontrak_repositori_inventaris.dart';
import '../repositori/kontrak_repositori_transaksi.dart';

class CatatStokMasuk {
  final KontrakRepositoriInventaris _repoInventaris;
  final KontrakRepositoriTransaksi _repoTransaksi;
  static const _uuid = Uuid();

  CatatStokMasuk(this._repoInventaris, this._repoTransaksi);

  Future<({bool berhasil, String pesan})> jalankan({
    required String idBarang,
    required String namaSatuan,
    required double kuantitasMasuk,
    double? totalHargaKulakan, // Opsional / kondisional (bisa null)
    bool konsumsiPribadiKeluar = false,
    String? catatan,
  }) async {
    if (kuantitasMasuk <= 0) {
      return (berhasil: false, pesan: 'Kuantitas harus lebih dari nol.');
    }

    final barang = await _repoInventaris.ambilBarangBerdasarkanId(idBarang);
    if (barang == null) {
      return (berhasil: false, pesan: 'Barang tidak ditemukan.');
    }

    final operatorAktif = await _repoTransaksi.ambilOperatorAktif();
    final deltaDasar = barang.hitungPenguranganDasar(kuantitasMasuk, namaSatuan);

    double? hppPerDasarBaru;
    if (!konsumsiPribadiKeluar && totalHargaKulakan != null && totalHargaKulakan > 0 && deltaDasar > 0) {
      hppPerDasarBaru = totalHargaKulakan / deltaDasar;
    }

    final kejadian = KejadianStok(
      id: _uuid.v4(),
      idBarang: barang.id,
      idOperator: operatorAktif.id,
      jenisKejadian: konsumsiPribadiKeluar
          ? JenisKejadianStok.konsumsiPribadi
          : JenisKejadianStok.kulakanMasuk,
      deltaSatuanDasar: konsumsiPribadiKeluar ? -deltaDasar : deltaDasar,
      hppSaatKejadian: hppPerDasarBaru ?? barang.hppTerakhir,
      catatan: catatan ??
          (konsumsiPribadiKeluar
              ? 'Ambil sendiri ($kuantitasMasuk $namaSatuan)'
              : 'Kulakan masuk ($kuantitasMasuk $namaSatuan)'),
      waktuKejadian: DateTime.now(),
    );

    await _repoInventaris.catatKejadianStokTunggal(
      kejadian,
      perbaruiHppTerakhir: hppPerDasarBaru,
    );

    return (
    berhasil: true,
    pesan: konsumsiPribadiKeluar
        ? 'Pengambilan pribadi dicatat ke buku besar.'
        : 'Kulakan masuk berhasil dicatat.',
    );
  }
}