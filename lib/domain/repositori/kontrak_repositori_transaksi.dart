import '../entitas/akun_kasbon.dart';
import '../entitas/kejadian_stok.dart';
import '../entitas/makro_transaksi.dart';

abstract class KontrakRepositoriTransaksi {
  Future<List<MakroTransaksi>> ambilSemuaMakro();
  Future<void> simpanMakro(MakroTransaksi makro);
  Future<void> hapusMakro(String idMakro);

  Future<void> eksekusiTransaksiAtomik({
    required String idNota,
    required String idOperator,
    required String metodeBayar,
    required double totalTagihan,
    required double nominalKasbon,
    String? idPelangganKasbon,
    required String keteranganNota,
    required List<KejadianStok> daftarKejadianStok,
  });

  Future<double> hitungTotalOmzetHariIni();

  Future<List<OperatorWarung>> ambilDaftarOperator();
  Future<OperatorWarung> ambilOperatorAktif();
  Future<void> gantiOperatorAktif(String idOperator);
  Future<void> tambahOperatorBaru(String namaPanggilan);

  Future<List<AkunKasbon>> ambilDaftarPelangganKasbon();
  Future<void> tambahPelangganKasbon(String nama, double limitKredit);
  Future<void> catatPembayaranKasbon(String idPelanggan, double nominal, String keterangan);
}