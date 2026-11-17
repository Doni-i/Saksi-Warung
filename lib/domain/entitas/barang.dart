import 'satuan_barang.dart';

abstract class Barang {
  final String id;
  final String? kodeSku;
  final String namaBarang;
  final String kategori;
  final String satuanDasar;
  final double? hppTerakhir;
  final double batasStokMinimum;
  final double stokTercatatDasar;
  final int jumlahAnomaliTercatat;
  final bool aktif;
  final List<SatuanBarang> daftarSatuan;

  const Barang({
    required this.id,
    this.kodeSku,
    required this.namaBarang,
    required this.kategori,
    required this.satuanDasar,
    this.hppTerakhir,
    required this.batasStokMinimum,
    this.stokTercatatDasar = 0.0,
    this.jumlahAnomaliTercatat = 0,
    this.aktif = true,
    this.daftarSatuan = const [],
  });

  String get jenisBarang;
  bool get apakahStokMenipis => stokTercatatDasar <= batasStokMinimum;
  bool get apakahStokMinus => stokTercatatDasar < 0.0;

  double? get valuasiModalTercatat =>
      hppTerakhir != null ? stokTercatatDasar * hppTerakhir! : null;

  SatuanBarang cariSatuan(String namaSatuan) {
    return daftarSatuan.firstWhere(
          (s) => s.namaSatuan.toLowerCase() == namaSatuan.toLowerCase(),
      orElse: () => SatuanBarang(
        id: 'fallback_$id',
        idBarang: id,
        namaSatuan: satuanDasar,
        rasioKeDasar: 1.0,
        hargaJual: hppTerakhir ?? 0.0,
      ),
    );
  }

  double hitungPenguranganDasar(double kuantitasJual, String namaSatuan);
  double hitungTotalHarga(double kuantitasJual, String namaSatuan, {double? hargaOverride});

  Map<String, Object?> kePetaSqlMaster(String waktuBuat) => {
    'id': id,
    'kode_sku': kodeSku,
    'nama_barang': namaBarang,
    'kategori': kategori,
    'jenis_barang': jenisBarang,
    'satuan_dasar': satuanDasar,
    'hpp_terakhir': hppTerakhir,
    'batas_stok_minimum': batasStokMinimum,
    'aktif': aktif ? 1 : 0,
    'dibuat_pada': waktuBuat,
  };
}

class BarangKemasan extends Barang {
  const BarangKemasan({
    required super.id,
    super.kodeSku,
    required super.namaBarang,
    required super.kategori,
    required super.satuanDasar,
    super.hppTerakhir,
    required super.batasStokMinimum,
    super.stokTercatatDasar,
    super.jumlahAnomaliTercatat,
    super.aktif,
    super.daftarSatuan,
  });

  @override
  String get jenisBarang => 'KEMASAN';

  @override
  double hitungPenguranganDasar(double kuantitasJual, String namaSatuan) {
    final satuan = cariSatuan(namaSatuan);
    return satuan.konversiKeSatuanDasar(kuantitasJual);
  }

  @override
  double hitungTotalHarga(double kuantitasJual, String namaSatuan, {double? hargaOverride}) {
    if (hargaOverride != null) return kuantitasJual * hargaOverride;
    final satuan = cariSatuan(namaSatuan);
    return kuantitasJual * satuan.hargaJual;
  }
}

class BarangCurah extends Barang {
  const BarangCurah({
    required super.id,
    super.kodeSku,
    required super.namaBarang,
    required super.kategori,
    required super.satuanDasar,
    super.hppTerakhir,
    required super.batasStokMinimum,
    super.stokTercatatDasar,
    super.jumlahAnomaliTercatat,
    super.aktif,
    super.daftarSatuan,
  });

  @override
  String get jenisBarang => 'CURAH';

  @override
  double hitungPenguranganDasar(double kuantitasJual, String namaSatuan) {
    final unitLower = namaSatuan.toLowerCase();
    if (unitLower == 'kg' || unitLower == 'liter') {
      return kuantitasJual * 1000.0;
    }
    final satuan = cariSatuan(namaSatuan);
    return satuan.konversiKeSatuanDasar(kuantitasJual);
  }

  @override
  double hitungTotalHarga(double kuantitasJual, String namaSatuan, {double? hargaOverride}) {
    if (hargaOverride != null) return kuantitasJual * hargaOverride;
    final satuan = cariSatuan(namaSatuan);
    return kuantitasJual * satuan.hargaJual;
  }
}