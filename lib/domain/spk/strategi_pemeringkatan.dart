import '../entitas/hasil_peringkat_spk.dart';

abstract class StrategiPemeringkatan {
  List<HasilPeringkatSpk> hitungPeringkat(
      List<MetrikKandidatKulakan> kandidat,
      List<double> bobotKriteria,
      );
} 