import 'package:sqflite/sqflite.dart';
import '../../domain/entitas/entri_audit.dart';
import '../../domain/repositori/kontrak_repositori_audit.dart';
import '../../inti/basis_data/pengelola_basis_data.dart';

class ImplementasiRepositoriAudit implements KontrakRepositoriAudit {
  final PengelolaBasisData _pengelolaDb;

  ImplementasiRepositoriAudit(this._pengelolaDb);

  Future<Database> get _db => _pengelolaDb.basisData;

  String _kunciTanggal(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Future<List<RingkasanHarianAudit>> ambilRingkasanHarianAudit({int jumlahHari = 30}) async {
    final db = await _db;
    final sekarang = DateTime.now();
    final hariAwal = DateTime(sekarang.year, sekarang.month, sekarang.day)
        .subtract(Duration(days: jumlahHari - 1));
    final batasIso = hariAwal.toIso8601String();

    final petaHarian = <String, ({int normal, int anomali, int editMaster})>{};
    for (int i = 0; i < jumlahHari; i++) {
      final tgl = hariAwal.add(Duration(days: i));
      petaHarian[_kunciTanggal(tgl)] = (normal: 0, anomali: 0, editMaster: 0);
    }

    // 1. Stock & sales events
    final stokRows = await db.rawQuery('''
      SELECT
        substr(waktu_kejadian, 1, 10) AS tgl,
        SUM(CASE WHEN jenis_kejadian IN ('ANOMALI_STOK_MINUS', 'SELISIH_OPNAME') THEN 1 ELSE 0 END) AS jml_anomali,
        SUM(CASE WHEN jenis_kejadian NOT IN ('ANOMALI_STOK_MINUS', 'SELISIH_OPNAME') THEN 1 ELSE 0 END) AS jml_normal
      FROM buku_besar_stok
      WHERE waktu_kejadian >= ?
      GROUP BY substr(waktu_kejadian, 1, 10)
    ''', [batasIso]);

    for (final r in stokRows) {
      final tgl = r['tgl'] as String?;
      if (tgl != null && petaHarian.containsKey(tgl)) {
        final lama = petaHarian[tgl]!;
        petaHarian[tgl] = (
        normal: lama.normal + ((r['jml_normal'] as num?)?.toInt() ?? 0),
        anomali: lama.anomali + ((r['jml_anomali'] as num?)?.toInt() ?? 0),
        editMaster: lama.editMaster,
        );
      }
    }

    // 2. Master & shortcut changes
    final masterRows = await db.rawQuery('''
      SELECT
        substr(waktu_kejadian, 1, 10) AS tgl,
        COUNT(*) AS jml_edit
      FROM log_perubahan_master
      WHERE waktu_kejadian >= ?
      GROUP BY substr(waktu_kejadian, 1, 10)
    ''', [batasIso]);

    for (final r in masterRows) {
      final tgl = r['tgl'] as String?;
      if (tgl != null && petaHarian.containsKey(tgl)) {
        final lama = petaHarian[tgl]!;
        petaHarian[tgl] = (
        normal: lama.normal,
        anomali: lama.anomali,
        editMaster: lama.editMaster + ((r['jml_edit'] as num?)?.toInt() ?? 0),
        );
      }
    }

    // 3. Audit lock events (failed PINs count as anomalies)
    final kunciRows = await db.rawQuery('''
      SELECT
        substr(waktu_kejadian, 1, 10) AS tgl,
        SUM(CASE WHEN jenis_aktivitas LIKE '%GAGAL%' THEN 1 ELSE 0 END) AS jml_gagal,
        SUM(CASE WHEN jenis_aktivitas NOT LIKE '%GAGAL%' THEN 1 ELSE 0 END) AS jml_normal
      FROM log_audit_kunci
      WHERE waktu_kejadian >= ?
      GROUP BY substr(waktu_kejadian, 1, 10)
    ''', [batasIso]);

    for (final r in kunciRows) {
      final tgl = r['tgl'] as String?;
      if (tgl != null && petaHarian.containsKey(tgl)) {
        final lama = petaHarian[tgl]!;
        petaHarian[tgl] = (
        normal: lama.normal + ((r['jml_normal'] as num?)?.toInt() ?? 0),
        anomali: lama.anomali + ((r['jml_gagal'] as num?)?.toInt() ?? 0),
        editMaster: lama.editMaster,
        );
      }
    }

    return List.generate(jumlahHari, (i) {
      final tgl = hariAwal.add(Duration(days: i));
      final kunci = _kunciTanggal(tgl);
      final nilai = petaHarian[kunci]!;
      return RingkasanHarianAudit(
        tanggal: tgl,
        kunciTanggal: kunci,
        jumlahNormal: nilai.normal,
        jumlahAnomali: nilai.anomali,
        jumlahEditMaster: nilai.editMaster,
      );
    });
  }

  @override
  Future<int> hitungPerhatianMingguIni() async {
    final ringkasan = await ambilRingkasanHarianAudit(jumlahHari: 7);
    return ringkasan.fold<int>(0, (sum, item) => sum + item.totalPerhatian);
  }

  @override
  Future<List<EntriJejakAudit>> ambilTimelineAudit({
    KategoriAudit kategori = KategoriAudit.semua,
    String? filterTanggalIso,
    String? filterIdOperator,
    String? filterIdBarang,
    DateTime? sebelumWaktu,
    int batas = 50,
  }) async {
    final db = await _db;
    final hasil = <EntriJejakAudit>[];

    final opRows = await db.query('operator_warung');
    final petaOperator = <String, String>{
      for (final op in opRows) op['id'] as String: op['nama_panggilan'] as String,
    };

    // A. buku_besar_stok
    if (kategori == KategoriAudit.semua ||
        kategori == KategoriAudit.stokDanPenjualan ||
        kategori == KategoriAudit.anomaliDanOpname) {
      final where = <String>[];
      final args = <Object?>[];

      if (kategori == KategoriAudit.anomaliDanOpname) {
        where.add("b.jenis_kejadian IN ('ANOMALI_STOK_MINUS', 'SELISIH_OPNAME')");
      } else if (kategori == KategoriAudit.stokDanPenjualan) {
        where.add("b.jenis_kejadian NOT IN ('ANOMALI_STOK_MINUS', 'SELISIH_OPNAME')");
      }

      if (filterTanggalIso != null && filterTanggalIso.isNotEmpty) {
        where.add('substr(b.waktu_kejadian, 1, 10) = ?');
        args.add(filterTanggalIso);
      }
      if (filterIdOperator != null && filterIdOperator.isNotEmpty) {
        where.add('b.id_operator = ?');
        args.add(filterIdOperator);
      }
      if (filterIdBarang != null && filterIdBarang.isNotEmpty) {
        where.add('b.id_barang = ?');
        args.add(filterIdBarang);
      }
      if (sebelumWaktu != null) {
        where.add('b.waktu_kejadian < ?');
        args.add(sebelumWaktu.toIso8601String());
      }

      final klausaWhere = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
      final rows = await db.rawQuery('''
        SELECT
          b.*,
          m.nama_barang,
          m.satuan_dasar
        FROM buku_besar_stok b
        LEFT JOIN master_barang m ON b.id_barang = m.id
        $klausaWhere
        ORDER BY b.waktu_kejadian DESC, b.id DESC
        LIMIT ?
      ''', [...args, batas]);

      for (final r in rows) {
        final jenis = r['jenis_kejadian'] as String;
        final anomali = jenis == 'ANOMALI_STOK_MINUS' || jenis == 'SELISIH_OPNAME';
        final namaBarang = (r['nama_barang'] as String?) ?? (r['id_barang'] as String);
        final satuanDasar = (r['satuan_dasar'] as String?) ?? '';
        final delta = (r['delta_satuan_dasar'] as num).toDouble();
        final sebelum = (r['stok_sebelum'] as num?)?.toDouble();
        final sesudah = (r['stok_sesudah'] as num?)?.toDouble();
        final idOp = r['id_operator'] as String;
        final namaOp =
            (r['nama_operator_saat_itu'] as String?) ?? petaOperator[idOp] ?? idOp;

        hasil.add(
          EntriJejakAudit(
            id: 'stok_${r['id']}',
            kategori: anomali
                ? KategoriAudit.anomaliDanOpname
                : KategoriAudit.stokDanPenjualan,
            kodeAktivitas: jenis,
            judul: '$namaBarang • ${_labelJenisKejadianStok(jenis)}',
            subjudul: (r['catatan'] as String?)?.isNotEmpty == true
                ? r['catatan'] as String
                : 'Mutasi buku besar stok',
            detailPerubahan: sebelum != null && sesudah != null
                ? 'Saldo: ${_fmt(sebelum)} → ${_fmt(sesudah)} $satuanDasar (${delta >= 0 ? '+' : ''}${_fmt(delta)})'
                : 'Delta: ${delta >= 0 ? '+' : ''}${_fmt(delta)} $satuanDasar',
            idOperator: idOp,
            namaOperator: namaOp,
            idBarangTerkait: r['id_barang'] as String,
            namaBarangTerkait: namaBarang,
            stokSebelum: sebelum,
            deltaStok: delta,
            stokSesudah: sesudah,
            satuanDasar: satuanDasar,
            butuhPerhatian: anomali,
            waktuKejadian: DateTime.parse(r['waktu_kejadian'] as String),
          ),
        );
      }
    }

    // B. log_perubahan_master
    if (kategori == KategoriAudit.semua ||
        kategori == KategoriAudit.perubahanMaster) {
      final where = <String>[];
      final args = <Object?>[];

      if (filterTanggalIso != null && filterTanggalIso.isNotEmpty) {
        where.add('substr(waktu_kejadian, 1, 10) = ?');
        args.add(filterTanggalIso);
      }
      if (filterIdOperator != null && filterIdOperator.isNotEmpty) {
        where.add('id_operator = ?');
        args.add(filterIdOperator);
      }
      if (filterIdBarang != null && filterIdBarang.isNotEmpty) {
        where.add("entitas = 'BARANG' AND id_entitas = ?");
        args.add(filterIdBarang);
      }
      if (sebelumWaktu != null) {
        where.add('waktu_kejadian < ?');
        args.add(sebelumWaktu.toIso8601String());
      }

      final rows = await db.query(
        'log_perubahan_master',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: where.isEmpty ? null : args,
        orderBy: 'waktu_kejadian DESC, id DESC',
        limit: batas,
      );

      for (final r in rows) {
        final entitas = r['entitas'] as String;
        final jenisAksi = r['jenis_aksi'] as String;
        final namaEntitas = r['nama_entitas_saat_itu'] as String;
        final idOp = r['id_operator'] as String;
        final namaOp =
            (r['nama_operator_saat_itu'] as String?) ?? petaOperator[idOp] ?? idOp;

        hasil.add(
          EntriJejakAudit(
            id: 'mst_${r['id']}',
            kategori: KategoriAudit.perubahanMaster,
            kodeAktivitas: '${entitas}_$jenisAksi',
            judul: '$entitas ($jenisAksi): $namaEntitas',
            subjudul: r['ringkasan_perubahan'] as String,
            idOperator: idOp,
            namaOperator: namaOp,
            idBarangTerkait: entitas == 'BARANG' ? r['id_entitas'] as String : null,
            namaBarangTerkait: entitas == 'BARANG' ? namaEntitas : null,
            butuhPerhatian: jenisAksi == 'UBAH' || jenisAksi == 'ARSIP' || jenisAksi == 'HAPUS',
            waktuKejadian: DateTime.parse(r['waktu_kejadian'] as String),
          ),
        );
      }
    }

    // C. log_audit_kunci (skip when filtering for a specific item)
    if ((filterIdBarang == null || filterIdBarang.isEmpty) &&
        (kategori == KategoriAudit.semua ||
            kategori == KategoriAudit.keamananKunci ||
            kategori == KategoriAudit.anomaliDanOpname)) {
      final where = <String>[];
      final args = <Object?>[];

      if (kategori == KategoriAudit.anomaliDanOpname) {
        where.add("jenis_aktivitas LIKE '%GAGAL%'");
      }
      if (filterTanggalIso != null && filterTanggalIso.isNotEmpty) {
        where.add('substr(waktu_kejadian, 1, 10) = ?');
        args.add(filterTanggalIso);
      }
      if (filterIdOperator != null && filterIdOperator.isNotEmpty) {
        where.add('id_operator = ?');
        args.add(filterIdOperator);
      }
      if (sebelumWaktu != null) {
        where.add('waktu_kejadian < ?');
        args.add(sebelumWaktu.toIso8601String());
      }

      final rows = await db.query(
        'log_audit_kunci',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: where.isEmpty ? null : args,
        orderBy: 'waktu_kejadian DESC, id DESC',
        limit: batas,
      );

      for (final r in rows) {
        final jenis = r['jenis_aktivitas'] as String;
        final idOp = r['id_operator'] as String;
        final gagal = jenis.contains('GAGAL');

        hasil.add(
          EntriJejakAudit(
            id: 'knc_${r['id']}',
            kategori: KategoriAudit.keamananKunci,
            kodeAktivitas: jenis,
            judul: 'KEAMANAN SHIFT: $jenis',
            subjudul: (r['keterangan'] as String?) ?? 'Aktivitas kunci layar audit',
            idOperator: idOp,
            namaOperator: petaOperator[idOp] ?? idOp,
            butuhPerhatian: gagal,
            waktuKejadian: DateTime.parse(r['waktu_kejadian'] as String),
          ),
        );
      }
    }

    hasil.sort((a, b) => b.waktuKejadian.compareTo(a.waktuKejadian));
    if (hasil.length > batas) {
      return hasil.sublist(0, batas);
    }
    return hasil;
  }

  String _labelJenisKejadianStok(String jenis) {
    switch (jenis) {
      case 'PENJUALAN_KELUAR':
        return 'Penjualan Keluar';
      case 'KULAKAN_MASUK':
        return 'Kulakan Masuk';
      case 'SELISIH_OPNAME':
        return 'Selisih Stock Opname';
      case 'ANOMALI_STOK_MINUS':
        return 'Anomali Stok Minus';
      case 'KONSUMSI_PRIBADI':
        return 'Ambil Sendiri';
      default:
        return jenis;
    }
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}