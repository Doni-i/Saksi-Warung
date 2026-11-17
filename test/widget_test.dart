import 'package:flutter_test/flutter_test.dart';
import 'package:saksi_warung/domain/entitas/makro_transaksi.dart';
import 'package:saksi_warung/domain/spk/kalkulator_bobot_ahp.dart';
import 'package:saksi_warung/inti/keamanan/pengelola_kunci_audit.dart';

void main() {
  test('AHP default matrix is consistent (CR < 0.10)', () {
    final ahp = KalkulatorBobotAhp();
    final hasil = ahp.hitungBobot(KalkulatorBobotAhp.matriksBawaan());
    expect(hasil.konsisten, isTrue);
  });

  test('MakroTransaksi computes fractional measurement totals accurately', () {
    const makro = MakroTransaksi(
      id: 'mkr_beras_setengah',
      labelTombol: 'Beras Medium (0.5 Kg)',
      idBarang: 'brg_beras_medium',
      namaSatuan: 'Kg',
      kuantitasBawaan: 0.5,
      hargaSatuanBawaan: 15000.0,
    );
    expect(makro.totalNominalBawaan, 7500.0);
    final diubah = makro.copyWith(kuantitasBawaan: 0.25);
    expect(diubah.totalNominalBawaan, 3750.0);
  });

  test('PengelolaKunciAudit hashes PIN deterministically', () {
    final pk = PengelolaKunciAudit();
    expect(pk.hitungHashPin('1234'), equals(pk.hitungHashPin('1234')));
    expect(pk.hitungHashPin('1234'), isNot(equals(pk.hitungHashPin('4321'))));
  });
}