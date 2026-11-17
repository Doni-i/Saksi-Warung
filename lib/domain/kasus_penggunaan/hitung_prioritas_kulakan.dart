import '../entitas/hasil_peringkat_spk.dart';
import '../repositori/kontrak_repositori_spk.dart';
import '../spk/kalkulator_bobot_ahp.dart';
import '../spk/strategi_pemeringkatan.dart';

class LaporanSpkKulakan {
  final HasilEvaluasiAhp evaluasiAhp;
  final List<HasilPeringkatSpk> daftarPeringkat;

  const LaporanSpkKulakan({
    required this.evaluasiAhp,
    required this.daftarPeringkat,
  });
}

class HitungPrioritasKulakan {
  final KontrakRepositoriSpk _repoSpk;
  final KalkulatorBobotAhp _kalkulatorAhp;
  final StrategiPemeringkatan _strategiTopsis;

  HitungPrioritasKulakan(
      this._repoSpk,
      this._kalkulatorAhp,
      this._strategiTopsis,
      );

  Future<LaporanSpkKulakan> jalankan() async {
    final matriksAhp = await _repoSpk.muatMatriksPerbandinganAhp();
    final evaluasiAhp = _kalkulatorAhp.hitungBobot(matriksAhp);
    final kandidat = await _repoSpk.kumpulkanMetrikKandidat();
    final hasil = _strategiTopsis.hitungPeringkat(
      kandidat,
      evaluasiAhp.bobotTernormalisasi,
    );

    return LaporanSpkKulakan(
      evaluasiAhp: evaluasiAhp,
      daftarPeringkat: hasil,
    );
  }
}