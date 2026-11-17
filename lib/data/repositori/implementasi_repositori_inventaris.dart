import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entitas/barang.dart';
import '../../domain/entitas/kejadian_stok.dart';
import '../../domain/entitas/satuan_barang.dart';
import '../../domain/repositori/kontrak_repositori_inventaris.dart';
import '../../inti/basis_data/pengelola_basis_data.dart';

class ImplementasiRepositoriInventaris implements KontrakRepositoriInventaris {
  final PengelolaBasisData _pengelolaDb;
  static const _uuid = Uuid();

  ImplementasiRepositoriInventaris(this._pengelolaDb);

  Future<Database> get _db => _pengelolaDb.basisData;

  Future<({String id, String nama})> _ambilOperatorAktifTxn(Transaction txn) async {
    final rows = await txn.query(
      'operator_warung',
      where: 'aktif_sekarang = 1',
      limit: 1,
    );
    if (rows.isEmpty) {
      return (id: 'op_pemilik', nama: 'PEMILIK');
    }
    return (
    id: rows.first['id'] as String,
    nama: rows.first['nama_panggilan'] as String,
    );
  }

  @override
  Future<List<Barang>> ambilSemuaBarangAktif() async {
    final db = await _db;

    final barisBarang = await db.rawQuery('''
      SELECT 
        m.*,
        COALESCE(SUM(CASE WHEN b.jenis_kejadian IN ('ANOMALI_STOK_MINUS', 'SELISIH_OPNAME') THEN 1 ELSE 0 END), 0) AS total_anomali
      FROM master_barang m
      LEFT JOIN buku_besar_stok b ON m.id = b.id_barang
      WHERE m.aktif = 1
      GROUP BY m.id
      ORDER BY m.nama_barang ASC
    ''');

    final barisSatuan = await db.query('satuan_barang');
    final petaSatuan = <String, List<SatuanBarang>>{};
    for (final s in barisSatuan) {
      final satuan = SatuanBarang.dariPetaSql(s);
      petaSatuan.putIfAbsent(satuan.idBarang, () => []).add(satuan);
    }

    return barisBarang.map((row) {
      final id = row['id'] as String;
      return _petakanKeEntitasBarang(row, petaSatuan[id] ?? const []);
    }).toList();
  }

  @override
  Future<Barang?> ambilBarangBerdasarkanId(String idBarang) async {
    final db = await _db;

    final barisBarang = await db.rawQuery('''
      SELECT 
        m.*,
        COALESCE(SUM(CASE WHEN b.jenis_kejadian IN ('ANOMALI_STOK_MINUS', 'SELISIH_OPNAME') THEN 1 ELSE 0 END), 0) AS total_anomali
      FROM master_barang m
      LEFT JOIN buku_besar_stok b ON m.id = b.id_barang
      WHERE m.id = ?
      GROUP BY m.id
    ''', [idBarang]);

    if (barisBarang.isEmpty) return null;

    final barisSatuan = await db.query(
      'satuan_barang',
      where: 'id_barang = ?',
      whereArgs: [idBarang],
    );
    final daftarSatuan = barisSatuan.map(SatuanBarang.dariPetaSql).toList();

    return _petakanKeEntitasBarang(barisBarang.first, daftarSatuan);
  }

  @override
  Future<void> simpanBarangBaru(Barang barang, List<SatuanBarang> daftarSatuan) async {
    final db = await _db;
    final sekarang = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final operator = await _ambilOperatorAktifTxn(txn);
      final petaMaster = barang.kePetaSqlMaster(sekarang)
        ..['stok_tercatat_dasar'] = barang.stokTercatatDasar;

      await txn.insert(
        'master_barang',
        petaMaster,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete('satuan_barang', where: 'id_barang = ?', whereArgs: [barang.id]);
      for (final satuan in daftarSatuan) {
        await txn.insert('satuan_barang', satuan.kePetaSql());
      }

      final ringkasanSatuan = daftarSatuan
          .map((s) => '${s.namaSatuan}=Rp${s.hargaJual.toStringAsFixed(0)}')
          .join(', ');

      await txn.insert('log_perubahan_master', {
        'id': _uuid.v4(),
        'entitas': 'BARANG',
        'id_entitas': barang.id,
        'nama_entitas_saat_itu': barang.namaBarang,
        'jenis_aksi': 'TAMBAH',
        'id_operator': operator.id,
        'nama_operator_saat_itu': operator.nama,
        'ringkasan_perubahan':
        'Barang baru (${barang.jenisBarang}, ${barang.kategori}) • $ringkasanSatuan',
        'nilai_lama_json': null,
        'nilai_baru_json': jsonEncode({
          'nama_barang': barang.namaBarang,
          'kategori': barang.kategori,
          'jenis_barang': barang.jenisBarang,
          'satuan_dasar': barang.satuanDasar,
          'hpp_terakhir': barang.hppTerakhir,
          'batas_stok_minimum': barang.batasStokMinimum,
          'satuan': daftarSatuan
              .map((s) => {
            'nama': s.namaSatuan,
            'rasio': s.rasioKeDasar,
            'harga': s.hargaJual,
          })
              .toList(),
        }),
        'waktu_kejadian': sekarang,
      });
    });
  }

  @override
  Future<void> perbaruiMasterBarang(Barang barang, List<SatuanBarang> daftarSatuan) async {
    final db = await _db;
    final sekarang = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final operator = await _ambilOperatorAktifTxn(txn);
      final rowsLama = await txn.query(
        'master_barang',
        where: 'id = ?',
        whereArgs: [barang.id],
        limit: 1,
      );
      final satuanLamaRows = await txn.query(
        'satuan_barang',
        where: 'id_barang = ?',
        whereArgs: [barang.id],
      );

      await txn.update(
        'master_barang',
        {
          'kode_sku': barang.kodeSku,
          'nama_barang': barang.namaBarang,
          'kategori': barang.kategori,
          'jenis_barang': barang.jenisBarang,
          'satuan_dasar': barang.satuanDasar,
          'hpp_terakhir': barang.hppTerakhir,
          'batas_stok_minimum': barang.batasStokMinimum,
          'aktif': barang.aktif ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [barang.id],
      );

      await txn.delete('satuan_barang', where: 'id_barang = ?', whereArgs: [barang.id]);
      for (final satuan in daftarSatuan) {
        await txn.insert('satuan_barang', satuan.kePetaSql());
      }

      // Build human-readable & JSON diff for audit trail
      final perubahan = <String>[];
      final mapLama = <String, Object?>{};
      final mapBaru = <String, Object?>{};

      if (rowsLama.isNotEmpty) {
        final lama = rowsLama.first;
        if (lama['nama_barang'] != barang.namaBarang) {
          perubahan.add('Nama: ${lama['nama_barang']} → ${barang.namaBarang}');
          mapLama['nama_barang'] = lama['nama_barang'];
          mapBaru['nama_barang'] = barang.namaBarang;
        }
        final hppLama = (lama['hpp_terakhir'] as num?)?.toDouble();
        if (hppLama != barang.hppTerakhir) {
          perubahan.add(
            'HPP: ${hppLama != null ? 'Rp${hppLama.toStringAsFixed(0)}' : 'Kosong'} → ${barang.hppTerakhir != null ? 'Rp${barang.hppTerakhir!.toStringAsFixed(0)}' : 'Kosong'}',
          );
          mapLama['hpp_terakhir'] = hppLama;
          mapBaru['hpp_terakhir'] = barang.hppTerakhir;
        }
        final minLama = (lama['batas_stok_minimum'] as num).toDouble();
        if (minLama != barang.batasStokMinimum) {
          perubahan.add(
            'Batas Min: ${minLama.toStringAsFixed(0)} → ${barang.batasStokMinimum.toStringAsFixed(0)}',
          );
          mapLama['batas_stok_minimum'] = minLama;
          mapBaru['batas_stok_minimum'] = barang.batasStokMinimum;
        }
      }

      final petaHargaLama = <String, double>{
        for (final s in satuanLamaRows)
          s['nama_satuan'] as String: (s['harga_jual'] as num).toDouble(),
      };
      for (final sBaru in daftarSatuan) {
        final hargaLama = petaHargaLama[sBaru.namaSatuan];
        if (hargaLama == null) {
          perubahan.add('Satuan +${sBaru.namaSatuan}: Rp${sBaru.hargaJual.toStringAsFixed(0)}');
        } else if (hargaLama != sBaru.hargaJual) {
          perubahan.add(
            'Harga ${sBaru.namaSatuan}: Rp${hargaLama.toStringAsFixed(0)} → Rp${sBaru.hargaJual.toStringAsFixed(0)}',
          );
        }
      }
      mapLama['satuan'] = petaHargaLama;
      mapBaru['satuan'] = {
        for (final s in daftarSatuan) s.namaSatuan: s.hargaJual,
      };

      await txn.insert('log_perubahan_master', {
        'id': _uuid.v4(),
        'entitas': 'BARANG',
        'id_entitas': barang.id,
        'nama_entitas_saat_itu': barang.namaBarang,
        'jenis_aksi': 'UBAH',
        'id_operator': operator.id,
        'nama_operator_saat_itu': operator.nama,
        'ringkasan_perubahan':
        perubahan.isEmpty ? 'Pembaruan detail master barang' : perubahan.join(' • '),
        'nilai_lama_json': jsonEncode(mapLama),
        'nilai_baru_json': jsonEncode(mapBaru),
        'waktu_kejadian': sekarang,
      });

      final makroTerkait = await txn.query(
        'makro_transaksi',
        where: 'id_barang = ?',
        whereArgs: [barang.id],
      );

      for (final m in makroTerkait) {
        final satuanMakro = (m['nama_satuan'] as String).toLowerCase();
        final satuanCocok = daftarSatuan
            .where((s) => s.namaSatuan.toLowerCase() == satuanMakro)
            .firstOrNull;

        if (satuanCocok != null) {
          await txn.update(
            'makro_transaksi',
            {
              'nama_satuan': satuanCocok.namaSatuan,
              'harga_satuan_bawaan': satuanCocok.hargaJual,
            },
            where: 'id = ?',
            whereArgs: [m['id']],
          );
        } else if (daftarSatuan.isNotEmpty) {
          final satuanFallback = daftarSatuan.first;
          await txn.update(
            'makro_transaksi',
            {
              'nama_satuan': satuanFallback.namaSatuan,
              'harga_satuan_bawaan': satuanFallback.hargaJual,
            },
            where: 'id = ?',
            whereArgs: [m['id']],
          );
        }
      }
    });
  }

  @override
  Future<void> nonaktifkanBarang(String idBarang) async {
    final db = await _db;
    final sekarang = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final operator = await _ambilOperatorAktifTxn(txn);
      final rows = await txn.query(
        'master_barang',
        where: 'id = ?',
        whereArgs: [idBarang],
        limit: 1,
      );
      final namaBarang =
      rows.isNotEmpty ? rows.first['nama_barang'] as String : idBarang;
      final stokTerakhir = rows.isNotEmpty
          ? (rows.first['stok_tercatat_dasar'] as num?)?.toDouble() ?? 0.0
          : 0.0;

      await txn.update(
        'master_barang',
        {'aktif': 0},
        where: 'id = ?',
        whereArgs: [idBarang],
      );
      await txn.delete('makro_transaksi', where: 'id_barang = ?', whereArgs: [idBarang]);

      await txn.insert('log_perubahan_master', {
        'id': _uuid.v4(),
        'entitas': 'BARANG',
        'id_entitas': idBarang,
        'nama_entitas_saat_itu': namaBarang,
        'jenis_aksi': 'ARSIP',
        'id_operator': operator.id,
        'nama_operator_saat_itu': operator.nama,
        'ringkasan_perubahan':
        'Barang diarsipkan (sisa stok tercatat: ${stokTerakhir.toStringAsFixed(1)})',
        'nilai_lama_json': jsonEncode({'aktif': 1, 'stok_tercatat_dasar': stokTerakhir}),
        'nilai_baru_json': jsonEncode({'aktif': 0}),
        'waktu_kejadian': sekarang,
      });
    });
  }

  @override
  Future<void> catatKejadianStokTunggal(
      KejadianStok kejadian, {
        double? perbaruiHppTerakhir,
      }) async {
    final db = await _db;

    await db.transaction((txn) async {
      final operator = await _ambilOperatorAktifTxn(txn);
      final barangRows = await txn.query(
        'master_barang',
        columns: ['stok_tercatat_dasar'],
        where: 'id = ?',
        whereArgs: [kejadian.idBarang],
        limit: 1,
      );

      final stokSebelum = barangRows.isNotEmpty
          ? (barangRows.first['stok_tercatat_dasar'] as num).toDouble()
          : 0.0;
      final stokSesudah = stokSebelum + kejadian.deltaSatuanDasar;

      final petaKejadian = kejadian.kePetaSql()
        ..['stok_sebelum'] = stokSebelum
        ..['stok_sesudah'] = stokSesudah
        ..['nama_operator_saat_itu'] = kejadian.namaOperatorSaatItu ?? operator.nama;

      await txn.insert('buku_besar_stok', petaKejadian);

      final updateMaster = <String, Object?>{
        'stok_tercatat_dasar': stokSesudah,
      };
      if (perbaruiHppTerakhir != null && perbaruiHppTerakhir > 0) {
        updateMaster['hpp_terakhir'] = perbaruiHppTerakhir;
      }

      await txn.update(
        'master_barang',
        updateMaster,
        where: 'id = ?',
        whereArgs: [kejadian.idBarang],
      );
    });
  }

  @override
  Future<List<KejadianStok>> ambilRiwayatKejadianBarang(String idBarang, {int batas = 50}) async {
    final db = await _db;
    final rows = await db.query(
      'buku_besar_stok',
      where: 'id_barang = ?',
      whereArgs: [idBarang],
      orderBy: 'waktu_kejadian DESC',
      limit: batas,
    );
    return rows.map(KejadianStok.dariPetaSql).toList();
  }

  @override
  Future<List<KejadianStok>> ambilDaftarAnomaliTerbaru({int batas = 30}) async {
    final db = await _db;
    final rows = await db.query(
      'buku_besar_stok',
      where: "jenis_kejadian IN ('ANOMALI_STOK_MINUS', 'SELISIH_OPNAME')",
      orderBy: 'waktu_kejadian DESC',
      limit: batas,
    );
    return rows.map(KejadianStok.dariPetaSql).toList();
  }

  Barang _petakanKeEntitasBarang(
      Map<String, Object?> row,
      List<SatuanBarang> daftarSatuan,
      ) {
    final jenis = row['jenis_barang'] as String;
    final id = row['id'] as String;
    final kodeSku = row['kode_sku'] as String?;
    final namaBarang = row['nama_barang'] as String;
    final kategori = row['kategori'] as String;
    final satuanDasar = row['satuan_dasar'] as String;
    final hppTerakhir = (row['hpp_terakhir'] as num?)?.toDouble();
    final batasMin = (row['batas_stok_minimum'] as num).toDouble();
    final stokTercatat = (row['stok_tercatat_dasar'] as num?)?.toDouble() ?? 0.0;
    final totalAnomali = (row['total_anomali'] as num).toInt();
    final aktif = (row['aktif'] as int) == 1;

    if (jenis == 'CURAH') {
      return BarangCurah(
        id: id,
        kodeSku: kodeSku,
        namaBarang: namaBarang,
        kategori: kategori,
        satuanDasar: satuanDasar,
        hppTerakhir: hppTerakhir,
        batasStokMinimum: batasMin,
        stokTercatatDasar: stokTercatat,
        jumlahAnomaliTercatat: totalAnomali,
        aktif: aktif,
        daftarSatuan: daftarSatuan,
      );
    }

    return BarangKemasan(
      id: id,
      kodeSku: kodeSku,
      namaBarang: namaBarang,
      kategori: kategori,
      satuanDasar: satuanDasar,
      hppTerakhir: hppTerakhir,
      batasStokMinimum: batasMin,
      stokTercatatDasar: stokTercatat,
      jumlahAnomaliTercatat: totalAnomali,
      aktif: aktif,
      daftarSatuan: daftarSatuan,
    );
  }
}