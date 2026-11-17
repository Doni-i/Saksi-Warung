import 'package:uuid/uuid.dart';
import '../../inti/kejadian/bus_kejadian_domain.dart';
import '../entitas/kejadian_stok.dart';
import '../repositori/kontrak_repositori_inventaris.dart';
import '../repositori/kontrak_repositori_transaksi.dart';

class RekonsiliasiStokOpname {
  final KontrakRepositoriInventaris _repoInventaris;
  final KontrakRepositoriTransaksi _repoTransaksi;
  static const _uuid = Uuid();

  RekonsiliasiStokOpname(this._repoInventaris, this._repoTransaksi);

  Future<({bool berhasil, String pesan, double selisihDasar})> jalankan({
    required String idBarang,
    required double jumlahFisikTerhitungDasar,
    String? catatanOpname,
  }) async {
    if (jumlahFisikTerhitungDasar < 0) {
      return (
      berhasil: false,
      pesan: 'Hitungan fisik di rak tidak boleh bernilai negatif.',
      selisihDasar: 0.0,
      );
    }

    final barang = await _repoInventaris.ambilBarangBerdasarkanId(idBarang);
    if (barang == null) {
      return (berhasil: false, pesan: 'Barang tidak ditemukan.', selisihDasar: 0.0);
    }

    final selisih = jumlahFisikTerhitungDasar - barang.stokTercatatDasar;
    if (selisih.abs() < 0.0001) {
      return (
      berhasil: true,
      pesan: 'Stok fisik sesuai dengan catatan buku besar (Selisih 0).',
      selisihDasar: 0.0,
      );
    }

    final operatorAktif = await _repoTransaksi.ambilOperatorAktif();
    final sekarang = DateTime.now();

    final kejadianOpname = KejadianStok(
      id: _uuid.v4(),
      idBarang: barang.id,
      idOperator: operatorAktif.id,
      jenisKejadian: JenisKejadianStok.selisihOpname,
      deltaSatuanDasar: selisih,
      hppSaatKejadian: barang.hppTerakhir,
      catatan: catatanOpname ??
          'OPNAME: Buku ${barang.stokTercatatDasar.toStringAsFixed(1)} vs Fisik ${jumlahFisikTerhitungDasar.toStringAsFixed(1)} (Selisih ${selisih >= 0 ? '+' : ''}${selisih.toStringAsFixed(1)} ${barang.satuanDasar})',
      waktuKejadian: sekarang,
    );

    await _repoInventaris.catatKejadianStokTunggal(kejadianOpname);

    BusKejadianDomain.instansi.terbitkan(
      KejadianSelisihOpnameTerdeteksi(
        idBarang: barang.id,
        namaBarang: barang.namaBarang,
        selisihDasar: selisih,
        waktuTerjadi: sekarang,
      ),
    );

    return (
    berhasil: true,
    pesan:
    'Selisih opname ${selisih >= 0 ? '+' : ''}${selisih.toStringAsFixed(1)} ${barang.satuanDasar} dicatat ke log audit.',
    selisihDasar: selisih,
    );
  }
}