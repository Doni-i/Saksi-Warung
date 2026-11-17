import '../entitas/barang.dart';
import '../entitas/kejadian_stok.dart';
import '../entitas/satuan_barang.dart';

abstract class KontrakRepositoriInventaris {
  Future<List<Barang>> ambilSemuaBarangAktif();
  Future<Barang?> ambilBarangBerdasarkanId(String idBarang);
  Future<void> simpanBarangBaru(Barang barang, List<SatuanBarang> daftarSatuan);
  Future<void> perbaruiMasterBarang(Barang barang, List<SatuanBarang> daftarSatuan);
  Future<void> nonaktifkanBarang(String idBarang);
  Future<void> catatKejadianStokTunggal(KejadianStok kejadian, {double? perbaruiHppTerakhir});
  Future<List<KejadianStok>> ambilRiwayatKejadianBarang(String idBarang, {int batas = 50});
  Future<List<KejadianStok>> ambilDaftarAnomaliTerbaru({int batas = 30});
}