import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../domain/entitas/hasil_peringkat_spk.dart';
import '../../domain/repositori/kontrak_repositori_spk.dart';
import '../../domain/spk/kalkulator_bobot_ahp.dart';
import '../../inti/basis_data/pengelola_basis_data.dart';

class ImplementasiRepositoriSpk implements KontrakRepositoriSpk {
  final PengelolaBasisData _pengelolaDb;
  static const _kunciMatriksAhp = 'matriks_bobot_ahp_v1';

  ImplementasiRepositoriSpk(this._pengelolaDb);

  Future<Database> get _db => _pengelolaDb.basisData;

  @override
  Future<List<MetrikKandidatKulakan>> kumpulkanMetrikKandidat() async {
    final db = await _db;
    final batas7Hari = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

    final rows = await db.rawQuery('''
      SELECT 
        m.id,
        m.nama_barang,
        m.satuan_dasar,
        m.hpp_terakhir,
        m.batas_stok_minimum,
        COALESCE(SUM(b.delta_satuan_dasar), 0.0) AS stok_dasar,
        COALESCE(SUM(
          CASE 
            WHEN b.jenis_kejadian = 'PENJUALAN_KELUAR' AND b.waktu_kejadian >= ? 
            THEN ABS(b.delta_satuan_dasar) 
            ELSE 0.0 
          END
        ), 0.0) AS keluar_7_hari,
        COALESCE(SUM(
          CASE 
            WHEN b.jenis_kejadian IN ('ANOMALI_STOK_MINUS', 'SELISIH_OPNAME') 
            THEN 1 
            ELSE 0 
          END
        ), 0) AS frekuensi_anomali,
        (
          SELECT MAX(s.harga_jual / s.rasio_ke_dasar)
          FROM satuan_barang s
          WHERE s.id_barang = m.id AND s.rasio_ke_dasar > 0
        ) AS harga_jual_dasar_maks
      FROM master_barang m
      LEFT JOIN buku_besar_stok b ON m.id = b.id_barang
      WHERE m.aktif = 1
      GROUP BY m.id
    ''', [batas7Hari]);

    return rows.map((r) {
      final hpp = (r['hpp_terakhir'] as num?)?.toDouble();
      final hargaJualDasar = (r['harga_jual_dasar_maks'] as num?)?.toDouble();

      double? marginPersen;
      if (hpp != null && hpp > 0 && hargaJualDasar != null && hargaJualDasar > 0) {
        marginPersen = ((hargaJualDasar - hpp) / hargaJualDasar) * 100.0;
      }

      return MetrikKandidatKulakan(
        idBarang: r['id'] as String,
        namaBarang: r['nama_barang'] as String,
        satuanDasar: r['satuan_dasar'] as String,
        stokTercatatDasar: (r['stok_dasar'] as num).toDouble(),
        batasStokMinimum: (r['batas_stok_minimum'] as num).toDouble(),
        kecepatanKeluar7Hari: (r['keluar_7_hari'] as num).toDouble(),
        marginPersen: marginPersen,
        frekuensiAnomali: (r['frekuensi_anomali'] as num).toInt(),
      );
    }).toList();
  }

  @override
  Future<List<List<double>>> muatMatriksPerbandinganAhp() async {
    final db = await _db;
    final rows = await db.query(
      'pengaturan_sistem',
      where: 'kunci = ?',
      whereArgs: [_kunciMatriksAhp],
    );

    if (rows.isEmpty) {
      return KalkulatorBobotAhp.matriksBawaan();
    }

    try {
      final decoded = jsonDecode(rows.first['nilai'] as String) as List<dynamic>;
      return decoded
          .map((baris) => (baris as List<dynamic>).map((v) => (v as num).toDouble()).toList())
          .toList();
    } catch (_) {
      return KalkulatorBobotAhp.matriksBawaan();
    }
  }

  @override
  Future<void> simpanMatriksPerbandinganAhp(List<List<double>> matriks) async {
    final db = await _db;
    await db.insert(
      'pengaturan_sistem',
      {
        'kunci': _kunciMatriksAhp,
        'nilai': jsonEncode(matriks),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}