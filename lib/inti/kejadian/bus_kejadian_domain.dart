import 'dart:async';

abstract class KejadianDomain {
  final DateTime waktuTerjadi;
  KejadianDomain({DateTime? waktuTerjadi}) : waktuTerjadi = waktuTerjadi ?? DateTime.now();
}

class KejadianAnomaliStokMinus extends KejadianDomain {
  final String idBarang;
  final String namaBarang;
  final double stokSetelahTransaksi;
  final String idOperator;

  KejadianAnomaliStokMinus({
    required this.idBarang,
    required this.namaBarang,
    required this.stokSetelahTransaksi,
    required this.idOperator,
    super.waktuTerjadi,
  });
}

class KejadianSelisihOpnameTerdeteksi extends KejadianDomain {
  final String idBarang;
  final String namaBarang;
  final double selisihDasar;

  KejadianSelisihOpnameTerdeteksi({
    required this.idBarang,
    required this.namaBarang,
    required this.selisihDasar,
    super.waktuTerjadi,
  });
}

class BusKejadianDomain {
  BusKejadianDomain._internal();
  static final BusKejadianDomain instansi = BusKejadianDomain._internal();

  final StreamController<KejadianDomain> _pengontrol = StreamController<KejadianDomain>.broadcast();

  Stream<KejadianDomain> get aliranKejadian => _pengontrol.stream;

  void terbitkan(KejadianDomain kejadian) {
    if (!_pengontrol.isClosed) {
      _pengontrol.add(kejadian);
    }
  }

  void tutup() {
    _pengontrol.close();
  }
}