import 'package:uuid/uuid.dart';
import '../../inti/kejadian/bus_kejadian_domain.dart';
import '../entitas/kejadian_stok.dart';
import '../repositori/kontrak_repositori_inventaris.dart';
import '../repositori/kontrak_repositori_transaksi.dart';

class HasilEksekusiTransaksi {
  final bool berhasil;
  final String pesan;
  final bool memicuAnomaliStokMinus;

  const HasilEksekusiTransaksi({
    required this.berhasil,
    required this.pesan,
    this.memicuAnomaliStokMinus = false,
  });
}

class EksekusiTransaksiMakro {
  final KontrakRepositoriInventaris _repoInventaris;
  final KontrakRepositoriTransaksi _repoTransaksi;
  static const _uuid = Uuid();

  EksekusiTransaksiMakro(this._repoInventaris, this._repoTransaksi);

  Future<HasilEksekusiTransaksi> jalankan({
    required String idBarang,
    required String namaSatuan,
    required double kuantitas,
    double? hargaSatuanOverride,
    required String metodeBayar, // 'TUNAI' | 'KASBON' | 'CAMPURAN'
    String? idPelangganKasbon,
    double nominalTunaiDibayar = 0.0,
    String? catatanTambahan,
  }) async {
    if (kuantitas <= 0) {
      return const HasilEksekusiTransaksi(
        berhasil: false,
        pesan: 'Kuantitas transaksi harus lebih dari nol.',
      );
    }

    final barang = await _repoInventaris.ambilBarangBerdasarkanId(idBarang);
    if (barang == null) {
      return const HasilEksekusiTransaksi(
        berhasil: false,
        pesan: 'Barang tidak ditemukan di master inventaris.',
      );
    }

    final operatorAktif = await _repoTransaksi.ambilOperatorAktif();
    final sekarang = DateTime.now();
    final idNota = _uuid.v4();

    final totalTagihan = barang.hitungTotalHarga(
      kuantitas,
      namaSatuan,
      hargaOverride: hargaSatuanOverride,
    );
    final penguranganDasar = barang.hitungPenguranganDasar(kuantitas, namaSatuan);

    // Hitung alokasi kasbon
    double nominalKasbon = 0.0;
    if (metodeBayar == 'KASBON') {
      nominalKasbon = totalTagihan;
    } else if (metodeBayar == 'CAMPURAN') {
      nominalKasbon = (totalTagihan - nominalTunaiDibayar).clamp(0.0, totalTagihan);
    }

    if (nominalKasbon > 0) {
      if (idPelangganKasbon == null || idPelangganKasbon.isEmpty) {
        return const HasilEksekusiTransaksi(
          berhasil: false,
          pesan: 'Pilih pelanggan kasbon terlebih dahulu.',
        );
      }
      final daftarPelanggan = await _repoTransaksi.ambilDaftarPelangganKasbon();
      final pelanggan = daftarPelanggan.where((p) => p.id == idPelangganKasbon).firstOrNull;
      if (pelanggan == null) {
        return const HasilEksekusiTransaksi(
          berhasil: false,
          pesan: 'Akun pelanggan kasbon tidak valid.',
        );
      }
      if (!pelanggan.bolehTambahHutang(nominalKasbon)) {
        return const HasilEksekusiTransaksi(
          berhasil: false,
          pesan: 'DITOLAK: Nominal kasbon melampaui batas plafon kredit pelanggan.',
        );
      }
    }

    final daftarKejadian = <KejadianStok>[
      KejadianStok(
        id: _uuid.v4(),
        idBarang: barang.id,
        idOperator: operatorAktif.id,
        jenisKejadian: JenisKejadianStok.penjualanKeluar,
        deltaSatuanDasar: -penguranganDasar,
        hppSaatKejadian: barang.hppTerakhir,
        idReferensi: idNota,
        catatan: catatanTambahan ?? 'Jual $kuantitas $namaSatuan',
        waktuKejadian: sekarang,
      ),
    ];

    // Aturan Anti-Smoothing: Tidak memblokir penjualan saat stok <= 0,
    // tetapi mencatat kejadian ANOMALI_STOK_MINUS secara eksplisit.
    final proyeksiStokAkhir = barang.stokTercatatDasar - penguranganDasar;
    final terjadiAnomaliMinus = proyeksiStokAkhir < 0.0;

    if (terjadiAnomaliMinus) {
      daftarKejadian.add(
        KejadianStok(
          id: _uuid.v4(),
          idBarang: barang.id,
          idOperator: operatorAktif.id,
          jenisKejadian: JenisKejadianStok.anomaliStokMinus,
          deltaSatuanDasar: 0.0, // Penanda audit; delta fisik sudah dicatat di penjualanKeluar
          hppSaatKejadian: barang.hppTerakhir,
          idReferensi: idNota,
          catatan:
          'ANOMALI: Proyeksi stok menjadi ${proyeksiStokAkhir.toStringAsFixed(1)} ${barang.satuanDasar} (kulakan belum dicatat / selisih satuan).',
          waktuKejadian: sekarang,
        ),
      );
    }

    await _repoTransaksi.eksekusiTransaksiAtomik(
      idNota: idNota,
      idOperator: operatorAktif.id,
      metodeBayar: metodeBayar,
      totalTagihan: totalTagihan,
      nominalKasbon: nominalKasbon,
      idPelangganKasbon: idPelangganKasbon,
      keteranganNota: '${barang.namaBarang} ($kuantitas $namaSatuan)',
      daftarKejadianStok: daftarKejadian,
    );

    if (terjadiAnomaliMinus) {
      BusKejadianDomain.instansi.terbitkan(
        KejadianAnomaliStokMinus(
          idBarang: barang.id,
          namaBarang: barang.namaBarang,
          stokSetelahTransaksi: proyeksiStokAkhir,
          idOperator: operatorAktif.id,
          waktuTerjadi: sekarang,
        ),
      );
    }

    return HasilEksekusiTransaksi(
      berhasil: true,
      pesan: terjadiAnomaliMinus
          ? 'Transaksi tercatat (Peringatan: Anomali stok minus dicatat).'
          : 'Transaksi berhasil dicatat.',
      memicuAnomaliStokMinus: terjadiAnomaliMinus,
    );
  }
}