import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entitas/akun_kasbon.dart';
import '../../domain/entitas/kejadian_stok.dart';
import '../../domain/entitas/makro_transaksi.dart';
import '../../domain/repositori/kontrak_repositori_transaksi.dart';
import '../../inti/basis_data/pengelola_basis_data.dart';

class ImplementasiRepositoriTransaksi implements KontrakRepositoriTransaksi {
  final PengelolaBasisData _pengelolaDb;
  static const _uuid = Uuid();

  ImplementasiRepositoriTransaksi(this._pengelolaDb);

  Future<Database> get _db => _pengelolaDb.basisData;

  @override
  Future<List<MakroTransaksi>> ambilSemuaMakro() async {
    final db = await _db;
    final rows = await db.query('makro_transaksi', orderBy: 'urutan_tampil ASC');
    return rows.map(MakroTransaksi.dariPetaSql).toList();
  }

  @override
  Future<void> simpanMakro(MakroTransaksi makro) async {
    final db = await _db;
    final sekarang = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final opRows = await txn.query(
        'operator_warung',
        where: 'aktif_sekarang = 1',
        limit: 1,
      );
      final idOp = opRows.isNotEmpty ? opRows.first['id'] as String : 'op_pemilik';
      final namaOp =
      opRows.isNotEmpty ? opRows.first['nama_panggilan'] as String : 'PEMILIK';

      final lamaRows = await txn.query(
        'makro_transaksi',
        where: 'id = ?',
        whereArgs: [makro.id],
        limit: 1,
      );

      await txn.insert(
        'makro_transaksi',
        makro.kePetaSql(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final adalahBaru = lamaRows.isEmpty;
      await txn.insert('log_perubahan_master', {
        'id': _uuid.v4(),
        'entitas': 'PINTASAN',
        'id_entitas': makro.id,
        'nama_entitas_saat_itu': makro.labelTombol,
        'jenis_aksi': adalahBaru ? 'TAMBAH' : 'UBAH',
        'id_operator': idOp,
        'nama_operator_saat_itu': namaOp,
        'ringkasan_perubahan':
        '${adalahBaru ? 'Pintasan baru' : 'Pintasan diubah'}: ${makro.kuantitasBawaan} ${makro.namaSatuan} @ Rp${makro.hargaSatuanBawaan.toStringAsFixed(0)}',
        'nilai_lama_json': adalahBaru ? null : jsonEncode(lamaRows.first),
        'nilai_baru_json': jsonEncode(makro.kePetaSql()),
        'waktu_kejadian': sekarang,
      });
    });
  }

  @override
  Future<void> hapusMakro(String idMakro) async {
    final db = await _db;
    final sekarang = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final opRows = await txn.query(
        'operator_warung',
        where: 'aktif_sekarang = 1',
        limit: 1,
      );
      final idOp = opRows.isNotEmpty ? opRows.first['id'] as String : 'op_pemilik';
      final namaOp =
      opRows.isNotEmpty ? opRows.first['nama_panggilan'] as String : 'PEMILIK';

      final lamaRows = await txn.query(
        'makro_transaksi',
        where: 'id = ?',
        whereArgs: [idMakro],
        limit: 1,
      );
      final labelLama =
      lamaRows.isNotEmpty ? lamaRows.first['label_tombol'] as String : idMakro;

      await txn.delete('makro_transaksi', where: 'id = ?', whereArgs: [idMakro]);

      await txn.insert('log_perubahan_master', {
        'id': _uuid.v4(),
        'entitas': 'PINTASAN',
        'id_entitas': idMakro,
        'nama_entitas_saat_itu': labelLama,
        'jenis_aksi': 'HAPUS',
        'id_operator': idOp,
        'nama_operator_saat_itu': namaOp,
        'ringkasan_perubahan': 'Pintasan dihapus dari laci: $labelLama',
        'nilai_lama_json': lamaRows.isNotEmpty ? jsonEncode(lamaRows.first) : null,
        'nilai_baru_json': null,
        'waktu_kejadian': sekarang,
      });
    });
  }

  @override
  Future<void> eksekusiTransaksiAtomik({
    required String idNota,
    required String idOperator,
    required String metodeBayar,
    required double totalTagihan,
    required double nominalKasbon,
    String? idPelangganKasbon,
    required String keteranganNota,
    required List<KejadianStok> daftarKejadianStok,
  }) async {
    final db = await _db;
    final sekarang = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final opRows = await txn.query(
        'operator_warung',
        columns: ['nama_panggilan'],
        where: 'id = ?',
        whereArgs: [idOperator],
        limit: 1,
      );
      final namaOp =
      opRows.isNotEmpty ? opRows.first['nama_panggilan'] as String : idOperator;

      await txn.insert('nota_penjualan', {
        'id': idNota,
        'id_operator': idOperator,
        'metode_bayar': metodeBayar,
        'id_pelanggan_kasbon': idPelangganKasbon,
        'total_tagihan': totalTagihan,
        'nominal_kasbon': nominalKasbon,
        'waktu_transaksi': sekarang,
      });

      final saldoPerBarang = <String, double>{};
      for (final kejadian in daftarKejadianStok) {
        if (!saldoPerBarang.containsKey(kejadian.idBarang)) {
          final barangRows = await txn.query(
            'master_barang',
            columns: ['stok_tercatat_dasar'],
            where: 'id = ?',
            whereArgs: [kejadian.idBarang],
            limit: 1,
          );
          saldoPerBarang[kejadian.idBarang] = barangRows.isNotEmpty
              ? (barangRows.first['stok_tercatat_dasar'] as num).toDouble()
              : 0.0;
        }

        final stokSebelum = saldoPerBarang[kejadian.idBarang]!;
        final stokSesudah = stokSebelum + kejadian.deltaSatuanDasar;
        saldoPerBarang[kejadian.idBarang] = stokSesudah;

        final petaKejadian = kejadian.kePetaSql()
          ..['stok_sebelum'] = stokSebelum
          ..['stok_sesudah'] = stokSesudah
          ..['nama_operator_saat_itu'] = kejadian.namaOperatorSaatItu ?? namaOp;
        await txn.insert('buku_besar_stok', petaKejadian);
      }

      for (final entry in saldoPerBarang.entries) {
        await txn.update(
          'master_barang',
          {'stok_tercatat_dasar': entry.value},
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }

      if (nominalKasbon > 0 && idPelangganKasbon != null) {
        await txn.insert('buku_besar_kasbon', {
          'id': _uuid.v4(),
          'id_pelanggan': idPelangganKasbon,
          'id_nota': idNota,
          'jenis_mutasi': 'TAMBAH_HUTANG',
          'nominal': nominalKasbon,
          'keterangan': 'Nota #$idNota: $keteranganNota',
          'waktu_mutasi': sekarang,
        });
      }
    });
  }

  @override
  Future<double> hitungTotalOmzetHariIni() async {
    final db = await _db;
    final awalHari = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final res = await db.rawQuery('''
      SELECT COALESCE(SUM(total_tagihan), 0.0) AS omzet
      FROM nota_penjualan
      WHERE waktu_transaksi >= ?
    ''', [awalHari.toIso8601String()]);
    return (res.first['omzet'] as num).toDouble();
  }

  @override
  Future<List<OperatorWarung>> ambilDaftarOperator() async {
    final db = await _db;
    final rows = await db.query('operator_warung', orderBy: 'rowid ASC');
    return rows.map(OperatorWarung.dariPetaSql).toList();
  }

  @override
  Future<OperatorWarung> ambilOperatorAktif() async {
    final db = await _db;
    final rows = await db.query('operator_warung', where: 'aktif_sekarang = 1', limit: 1);
    if (rows.isNotEmpty) return OperatorWarung.dariPetaSql(rows.first);
    final semua = await ambilDaftarOperator();
    return semua.first;
  }

  @override
  Future<void> gantiOperatorAktif(String idOperator) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update('operator_warung', {'aktif_sekarang': 0});
      await txn.update(
        'operator_warung',
        {'aktif_sekarang': 1},
        where: 'id = ?',
        whereArgs: [idOperator],
      );
    });
  }

  @override
  Future<void> tambahOperatorBaru(String namaPanggilan) async {
    final db = await _db;
    await db.insert('operator_warung', {
      'id': _uuid.v4(),
      'nama_panggilan': namaPanggilan.trim().toUpperCase(),
      'aktif_sekarang': 0,
    });
  }

  @override
  Future<List<AkunKasbon>> ambilDaftarPelangganKasbon() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT 
        p.*,
        COALESCE(SUM(CASE WHEN k.jenis_mutasi = 'TAMBAH_HUTANG' THEN k.nominal ELSE -k.nominal END), 0.0) AS saldo_hutang
      FROM pelanggan_kasbon p
      LEFT JOIN buku_besar_kasbon k ON p.id = k.id_pelanggan
      GROUP BY p.id
      ORDER BY p.nama ASC
    ''');
    return rows.map(AkunKasbon.dariPetaSql).toList();
  }

  @override
  Future<void> tambahPelangganKasbon(String nama, double limitKredit) async {
    final db = await _db;
    await db.insert('pelanggan_kasbon', {
      'id': _uuid.v4(),
      'nama': nama.trim(),
      'limit_kredit': limitKredit,
      'dibuat_pada': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> catatPembayaranKasbon(
      String idPelanggan,
      double nominalBayar,
      String keterangan,
      ) async {
    final db = await _db;
    await db.insert('buku_besar_kasbon', {
      'id': _uuid.v4(),
      'id_pelanggan': idPelanggan,
      'id_nota': null,
      'jenis_mutasi': 'BAYAR_CICILAN',
      'nominal': nominalBayar,
      'keterangan': keterangan,
      'waktu_mutasi': DateTime.now().toIso8601String(),
    });
  }
}