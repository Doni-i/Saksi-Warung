import 'package:flutter/foundation.dart';
import '../../domain/kasus_penggunaan/hitung_prioritas_kulakan.dart';
import '../../domain/repositori/kontrak_repositori_spk.dart';
import '../../domain/spk/kalkulator_bobot_ahp.dart';

class PengendaliSpk extends ChangeNotifier {
  final KontrakRepositoriSpk _repoSpk;
  final HitungPrioritasKulakan _hitungPrioritas;

  PengendaliSpk(this._repoSpk, this._hitungPrioritas);

  List<List<double>> matriksAhp = KalkulatorBobotAhp.matriksBawaan();
  LaporanSpkKulakan? laporanTerbaru;
  bool sedangMenghitung = false;

  Future<void> muatDanHitung() async {
    sedangMenghitung = true;
    notifyListeners();

    matriksAhp = await _repoSpk.muatMatriksPerbandinganAhp();
    laporanTerbaru = await _hitungPrioritas.jalankan();

    sedangMenghitung = false;
    notifyListeners();
  }

  Future<void> perbaruiPreferensiPasangan(int baris, int kolom, double skalaSaaty) async {
    if (baris == kolom || skalaSaaty <= 0) return;
    matriksAhp[baris][kolom] = skalaSaaty;
    matriksAhp[kolom][baris] = 1.0 / skalaSaaty;

    await _repoSpk.simpanMatriksPerbandinganAhp(matriksAhp);
    await muatDanHitung();
  }

  Future<void> resetMatriksBawaan() async {
    matriksAhp = KalkulatorBobotAhp.matriksBawaan();
    await _repoSpk.simpanMatriksPerbandinganAhp(matriksAhp);
    await muatDanHitung();
  }
}