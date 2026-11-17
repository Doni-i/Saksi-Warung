import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../basis_data/pengelola_basis_data.dart';

class LayananCadanganLokal {
  static const _penyimpananAman = FlutterSecureStorage();
  static const _kunciFrasa = 'saksi_warung_kunci_cadangan_v1';

  Future<String> _ambilAtauBuatFrasaSandi() async {
    String? frasa = await _penyimpananAman.read(key: _kunciFrasa);
    if (frasa == null || frasa.isEmpty) {
      frasa = 'SAKSI-WARUNG-LURING-AMAN';
      await _penyimpananAman.write(key: _kunciFrasa, value: frasa);
    }
    return frasa;
  }

  List<int> _turunkanKunciAes(String frasa) {
    final bersih = frasa.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '-');
    return sha256.convert(utf8.encode(bersih)).bytes;
  }

  Future<({bool berhasil, String pesan, String? jalurHasil})> eksporCadanganTerenkripsi({
    String? frasaKustom,
    String? direktoriTujuan,
  }) async {
    try {
      final jalurDb = PengelolaBasisData.instansi.jalurBerkasAktif;
      final berkasDb = File(jalurDb);
      if (!await berkasDb.exists()) {
        return (berhasil: false, pesan: 'Berkas basis data tidak ditemukan.', jalurHasil: null);
      }

      final frasa = (frasaKustom != null && frasaKustom.trim().isNotEmpty)
          ? frasaKustom
          : await _ambilAtauBuatFrasaSandi();

      final byteMentah = await berkasDb.readAsBytes();
      final kunci = enc.Key(Uint8List.fromList(_turunkanKunciAes(frasa)));
      final iv = enc.IV.fromSecureRandom(16);
      final pengenkripsi = enc.Encrypter(enc.AES(kunci, mode: enc.AESMode.cbc));
      final terenkripsi = pengenkripsi.encryptBytes(byteMentah, iv: iv);

      final muatanGabungan = Uint8List.fromList(iv.bytes + terenkripsi.bytes);

      final folderTarget = direktoriTujuan != null
          ? Directory(direktoriTujuan)
          : await getApplicationDocumentsDirectory();
      if (!await folderTarget.exists()) {
        await folderTarget.create(recursive: true);
      }

      final capWaktu = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final berkasTujuan = File(p.join(folderTarget.path, 'saksi_warung_$capWaktu.enc'));
      await berkasTujuan.writeAsBytes(muatanGabungan, flush: true);

      return (
      berhasil: true,
      pesan: 'Cadangan terenkripsi berhasil disimpan.',
      jalurHasil: berkasTujuan.path,
      );
    } catch (e) {
      return (berhasil: false, pesan: 'Gagal membuat cadangan: $e', jalurHasil: null);
    }
  }

  Future<({bool berhasil, String pesan})> imporCadanganTerenkripsi({
    required String jalurBerkasEnc,
    String? frasaKustom,
  }) async {
    final berkasSumber = File(jalurBerkasEnc);
    if (!await berkasSumber.exists()) {
      return (berhasil: false, pesan: 'Berkas cadangan tidak ditemukan.');
    }

    final jalurDbAktif = PengelolaBasisData.instansi.jalurBerkasAktif;
    final berkasDbAktif = File(jalurDbAktif);
    final berkasPengaman = File('$jalurDbAktif.pengaman');

    try {
      final seluruhByte = await berkasSumber.readAsBytes();
      if (seluruhByte.length <= 16) {
        return (berhasil: false, pesan: 'Struktur berkas cadangan korup.');
      }

      final frasa = (frasaKustom != null && frasaKustom.trim().isNotEmpty)
          ? frasaKustom
          : await _ambilAtauBuatFrasaSandi();

      final iv = enc.IV(Uint8List.fromList(seluruhByte.sublist(0, 16)));
      final cipherByte = Uint8List.fromList(seluruhByte.sublist(16));
      final kunci = enc.Key(Uint8List.fromList(_turunkanKunciAes(frasa)));
      final pengenkripsi = enc.Encrypter(enc.AES(kunci, mode: enc.AESMode.cbc));

      final hasilDekripsi = pengenkripsi.decryptBytes(enc.Encrypted(cipherByte), iv: iv);

      if (await berkasDbAktif.exists()) {
        await berkasDbAktif.copy(berkasPengaman.path);
      }

      await PengelolaBasisData.instansi.tutupBasisData();
      await berkasDbAktif.writeAsBytes(hasilDekripsi, flush: true);
      await PengelolaBasisData.instansi.inisialisasi();

      final db = await PengelolaBasisData.instansi.basisData;
      await db.rawQuery('SELECT COUNT(*) FROM master_barang');

      if (await berkasPengaman.exists()) {
        await berkasPengaman.delete();
      }

      return (berhasil: true, pesan: 'Pemulihan data berhasil.');
    } catch (e) {
      try {
        await PengelolaBasisData.instansi.tutupBasisData();
        if (await berkasPengaman.exists()) {
          await berkasPengaman.copy(jalurDbAktif);
        }
        await PengelolaBasisData.instansi.inisialisasi();
      } catch (_) {} finally {
        if (await berkasPengaman.exists()) {
          await berkasPengaman.delete();
        }
      }
      return (berhasil: false, pesan: 'Pemulihan gagal (kunci salah atau berkas rusak). Data awal dipertahankan.');
    }
  }
}