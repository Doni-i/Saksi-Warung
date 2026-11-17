import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../basis_data/pengelola_basis_data.dart';

class LogAuditKunci {
  final String id;
  final String idOperator;
  final String jenisAktivitas;
  final String? keterangan;
  final DateTime waktuKejadian;

  const LogAuditKunci({
    required this.id,
    required this.idOperator,
    required this.jenisAktivitas,
    this.keterangan,
    required this.waktuKejadian,
  });

  factory LogAuditKunci.dariPetaSql(Map<String, Object?> peta) => LogAuditKunci(
    id: peta['id'] as String,
    idOperator: peta['id_operator'] as String,
    jenisAktivitas: peta['jenis_aktivitas'] as String,
    keterangan: peta['keterangan'] as String?,
    waktuKejadian: DateTime.parse(peta['waktu_kejadian'] as String),
  );
}

class PengelolaKunciAudit extends ChangeNotifier {
  static const _uuid = Uuid();
  static const _saltPin = 'SAKSI_WARUNG_AUDIT_PIN_V1:';

  static const _kunciHashPin = 'hash_pin_audit';
  static const _kunciAuditAktif = 'kunci_audit_aktif';
  static const _kunciOtomatisLatar = 'kunci_otomatis_latar';
  static const _kunciTimeoutMenit = 'timeout_kunci_menit';

  String? _hashPinTersimpan;
  bool kunciAuditAktif = false;
  bool kunciSaatLatarBelakang = true;
  int timeoutIdleMenit = 3; // 0 = nonaktif
  bool sedangTerkunci = false;
  int percobaanGagalBeruntun = 0;
  String? alasanTerkunciTerakhir;
  List<LogAuditKunci> riwayatLogAudit = [];

  Timer? _timerIdle;
  String _idOperatorTerakhir = 'op_pemilik';

  bool get pinSudahDiatur =>
      _hashPinTersimpan != null && _hashPinTersimpan!.isNotEmpty;

  String hitungHashPin(String pinMentah) {
    final bersih = pinMentah.trim();
    return sha256.convert(utf8.encode('$_saltPin$bersih')).toString();
  }

  Future<void> inisialisasi({String? idOperatorAwal}) async {
    if (idOperatorAwal != null && idOperatorAwal.isNotEmpty) {
      _idOperatorTerakhir = idOperatorAwal;
    }

    final db = await PengelolaBasisData.instansi.basisData;
    final rows = await db.query(
      'pengaturan_sistem',
      where: 'kunci IN (?, ?, ?, ?)',
      whereArgs: [
        _kunciHashPin,
        _kunciAuditAktif,
        _kunciOtomatisLatar,
        _kunciTimeoutMenit,
      ],
    );

    final peta = <String, String>{
      for (final r in rows) r['kunci'] as String: r['nilai'] as String,
    };

    _hashPinTersimpan = peta[_kunciHashPin];
    kunciAuditAktif = peta[_kunciAuditAktif] == 'true';
    kunciSaatLatarBelakang = peta[_kunciOtomatisLatar] != 'false';
    timeoutIdleMenit = int.tryParse(peta[_kunciTimeoutMenit] ?? '3') ?? 3;

    if (pinSudahDiatur && kunciAuditAktif) {
      sedangTerkunci = true;
      alasanTerkunciTerakhir = 'Verifikasi sesi awal Saksi Warung';
      await _catatLog(
        idOperator: _idOperatorTerakhir,
        jenisAktivitas: 'KUNCI_SESI_AWAL',
        keterangan: 'Aplikasi dibuka dalam mode kunci audit aktif',
      );
    } else {
      sedangTerkunci = false;
      _mulaiUlangTimerIdle();
    }

    await muatLogAudit();
    notifyListeners();
  }

  Future<({bool berhasil, String pesan})> aturPinBaru({
    required String pinBaru,
    required String idOperator,
  }) async {
    final bersih = pinBaru.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(bersih)) {
      return (
      berhasil: false,
      pesan: 'PIN Audit harus terdiri dari 4 sampai 6 digit angka.',
      );
    }

    final hash = hitungHashPin(bersih);
    final db = await PengelolaBasisData.instansi.basisData;
    await db.insert(
      'pengaturan_sistem',
      {'kunci': _kunciHashPin, 'nilai': hash},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'pengaturan_sistem',
      {'kunci': _kunciAuditAktif, 'nilai': 'true'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _hashPinTersimpan = hash;
    kunciAuditAktif = true;
    _idOperatorTerakhir = idOperator;

    await _catatLog(
      idOperator: idOperator,
      jenisAktivitas: 'ATUR_PIN_AUDIT',
      keterangan: 'PIN layar audit diperbarui dan diaktifkan',
    );
    await muatLogAudit();
    _mulaiUlangTimerIdle();
    notifyListeners();

    return (berhasil: true, pesan: 'PIN Kunci Audit berhasil disimpan & aktif.');
  }

  Future<({bool berhasil, String pesan})> nonaktifkanKunciDenganPin({
    required String pinVerifikasi,
    required String idOperator,
  }) async {
    if (!pinSudahDiatur || hitungHashPin(pinVerifikasi) != _hashPinTersimpan) {
      await _catatLog(
        idOperator: idOperator,
        jenisAktivitas: 'GAGAL_NONAKTIF_PIN',
        keterangan: 'Percobaan menonaktifkan kunci audit dengan PIN salah',
      );
      await muatLogAudit();
      return (berhasil: false, pesan: 'PIN salah. Kunci audit tetap aktif.');
    }

    final db = await PengelolaBasisData.instansi.basisData;
    await db.insert(
      'pengaturan_sistem',
      {'kunci': _kunciAuditAktif, 'nilai': 'false'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    kunciAuditAktif = false;
    sedangTerkunci = false;
    _timerIdle?.cancel();

    await _catatLog(
      idOperator: idOperator,
      jenisAktivitas: 'NONAKTIF_KUNCI_AUDIT',
      keterangan: 'Kunci layar audit dinonaktifkan oleh operator',
    );
    await muatLogAudit();
    notifyListeners();

    return (berhasil: true, pesan: 'Kunci layar audit dinonaktifkan.');
  }

  Future<void> setelKunciLatarBelakang(bool aktif) async {
    kunciSaatLatarBelakang = aktif;
    final db = await PengelolaBasisData.instansi.basisData;
    await db.insert(
      'pengaturan_sistem',
      {'kunci': _kunciOtomatisLatar, 'nilai': aktif ? 'true' : 'false'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  Future<void> setelTimeoutIdle(int menit) async {
    timeoutIdleMenit = menit;
    final db = await PengelolaBasisData.instansi.basisData;
    await db.insert(
      'pengaturan_sistem',
      {'kunci': _kunciTimeoutMenit, 'nilai': '$menit'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _mulaiUlangTimerIdle();
    notifyListeners();
  }

  Future<void> kunciSekarang({
    required String idOperator,
    required String jenisAktivitas,
    required String keterangan,
  }) async {
    if (!pinSudahDiatur) return;
    _idOperatorTerakhir = idOperator;
    _timerIdle?.cancel();
    sedangTerkunci = true;
    alasanTerkunciTerakhir = keterangan;

    await _catatLog(
      idOperator: idOperator,
      jenisAktivitas: jenisAktivitas,
      keterangan: keterangan,
    );
    await muatLogAudit();
    notifyListeners();
  }

  Future<bool> verifikasiDanBuka({
    required String pinInput,
    required String idOperatorPembuka,
  }) async {
    if (!pinSudahDiatur) {
      sedangTerkunci = false;
      notifyListeners();
      return true;
    }

    final cocok = hitungHashPin(pinInput) == _hashPinTersimpan;
    if (cocok) {
      sedangTerkunci = false;
      percobaanGagalBeruntun = 0;
      alasanTerkunciTerakhir = null;
      _idOperatorTerakhir = idOperatorPembuka;

      await _catatLog(
        idOperator: idOperatorPembuka,
        jenisAktivitas: 'DIBUKA_PIN',
        keterangan: 'Layar audit dibuka dengan PIN valid',
      );
      await muatLogAudit();
      _mulaiUlangTimerIdle();
      notifyListeners();
      return true;
    }

    percobaanGagalBeruntun += 1;
    await _catatLog(
      idOperator: idOperatorPembuka,
      jenisAktivitas: 'GAGAL_PIN',
      keterangan: 'Percobaan buka PIN gagal ke-$percobaanGagalBeruntun',
    );
    await muatLogAudit();
    notifyListeners();
    return false;
  }

  void catatInteraksiPengguna({required String idOperatorAktif}) {
    _idOperatorTerakhir = idOperatorAktif;
    if (sedangTerkunci || !kunciAuditAktif || !pinSudahDiatur) return;
    _mulaiUlangTimerIdle();
  }

  Future<void> tanganiPerubahanLifecycle(
      AppLifecycleState state, {
        required String idOperatorAktif,
      }) async {
    _idOperatorTerakhir = idOperatorAktif;
    if (!kunciAuditAktif || !pinSudahDiatur || !kunciSaatLatarBelakang || sedangTerkunci) {
      return;
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      await kunciSekarang(
        idOperator: idOperatorAktif,
        jenisAktivitas: 'DIKUNCI_LATAR_BELAKANG',
        keterangan: 'Terkunci otomatis saat aplikasi keluar/layar mati',
      );
    }
  }

  void _mulaiUlangTimerIdle() {
    _timerIdle?.cancel();
    if (!kunciAuditAktif || !pinSudahDiatur || sedangTerkunci || timeoutIdleMenit <= 0) {
      return;
    }
    _timerIdle = Timer(Duration(minutes: timeoutIdleMenit), () {
      kunciSekarang(
        idOperator: _idOperatorTerakhir,
        jenisAktivitas: 'DIKUNCI_OTOMATIS_IDLE',
        keterangan: 'Terkunci otomatis setelah $timeoutIdleMenit menit tanpa aktivitas',
      );
    });
  }

  Future<void> _catatLog({
    required String idOperator,
    required String jenisAktivitas,
    required String keterangan,
  }) async {
    final db = await PengelolaBasisData.instansi.basisData;
    await db.insert('log_audit_kunci', {
      'id': _uuid.v4(),
      'id_operator': idOperator,
      'jenis_aktivitas': jenisAktivitas,
      'keterangan': keterangan,
      'waktu_kejadian': DateTime.now().toIso8601String(),
    });
  }

  Future<void> muatLogAudit({int batas = 25}) async {
    final db = await PengelolaBasisData.instansi.basisData;
    final rows = await db.query(
      'log_audit_kunci',
      orderBy: 'waktu_kejadian DESC',
      limit: batas,
    );
    riwayatLogAudit = rows.map(LogAuditKunci.dariPetaSql).toList();
  }

  @override
  void dispose() {
    _timerIdle?.cancel();
    super.dispose();
  }
}