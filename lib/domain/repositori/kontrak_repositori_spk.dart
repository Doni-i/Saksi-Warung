import '../entitas/hasil_peringkat_spk.dart';

abstract class KontrakRepositoriSpk {
  Future<List<MetrikKandidatKulakan>> kumpulkanMetrikKandidat();
  Future<List<List<double>>> muatMatriksPerbandinganAhp();
  Future<void> simpanMatriksPerbandinganAhp(List<List<double>> matriks);
}