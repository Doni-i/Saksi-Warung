import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class PengelolaBasisData {
  PengelolaBasisData._internal();
  static final PengelolaBasisData instansi = PengelolaBasisData._internal();

  Database? _db;
  String? _jalurBerkas;

  Future<Database> get basisData async {
    if (_db != null && _db!.isOpen) return _db!;
    await inisialisasi();
    return _db!;
  }

  String get jalurBerkasAktif => _jalurBerkas ?? '';

  Future<void> inisialisasi() async {
    final direktori = await getApplicationDocumentsDirectory();
    _jalurBerkas = p.join(direktori.path, 'saksi_warung.db');

    _db = await openDatabase(
      _jalurBerkas!,
      version: 3,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL;');
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _buatSkema(db);
        await _isiDataAwal(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _buatTabelAuditKunci(db);
          await db.insert(
            'pengaturan_sistem',
            {'kunci': 'kunci_audit_aktif', 'nilai': 'false'},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await db.insert(
            'pengaturan_sistem',
            {'kunci': 'kunci_otomatis_latar', 'nilai': 'true'},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await db.insert(
            'pengaturan_sistem',
            {'kunci': 'timeout_kunci_menit', 'nilai': '3'},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        if (oldVersion < 3) {
          await _migrasiKeVersi3(db);
        }
      },
    );
  }

  Future<void> tutupBasisData() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  Future<void> _migrasiKeVersi3(Database db) async {
    await db.execute(
      'ALTER TABLE master_barang ADD COLUMN stok_tercatat_dasar REAL NOT NULL DEFAULT 0.0;',
    );
    await db.execute('ALTER TABLE buku_besar_stok ADD COLUMN stok_sebelum REAL;');
    await db.execute('ALTER TABLE buku_besar_stok ADD COLUMN stok_sesudah REAL;');
    await db.execute('ALTER TABLE buku_besar_stok ADD COLUMN nama_operator_saat_itu TEXT;');

    await _buatTabelPerubahanMaster(db);
    await _buatIndeksAudit(db);

    // Backfill running stock snapshots chronologically per item
    final daftarOperator = await db.query('operator_warung');
    final petaOperator = <String, String>{
      for (final op in daftarOperator)
        op['id'] as String: op['nama_panggilan'] as String,
    };

    final daftarBarang = await db.query('master_barang', columns: ['id']);
    for (final b in daftarBarang) {
      final idBarang = b['id'] as String;
      final kejadian = await db.query(
        'buku_besar_stok',
        where: 'id_barang = ?',
        whereArgs: [idBarang],
        orderBy: 'waktu_kejadian ASC, rowid ASC',
      );

      double saldoBerjalan = 0.0;
      for (final k in kejadian) {
        final delta = (k['delta_satuan_dasar'] as num).toDouble();
        final sebelum = saldoBerjalan;
        final sesudah = sebelum + delta;
        saldoBerjalan = sesudah;

        final idOp = k['id_operator'] as String;
        await db.update(
          'buku_besar_stok',
          {
            'stok_sebelum': sebelum,
            'stok_sesudah': sesudah,
            'nama_operator_saat_itu': petaOperator[idOp] ?? idOp,
          },
          where: 'id = ?',
          whereArgs: [k['id']],
        );
      }

      await db.update(
        'master_barang',
        {'stok_tercatat_dasar': saldoBerjalan},
        where: 'id = ?',
        whereArgs: [idBarang],
      );
    }
  }

  Future<void> _buatTabelAuditKunci(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS log_audit_kunci (
        id TEXT PRIMARY KEY,
        id_operator TEXT NOT NULL,
        jenis_aktivitas TEXT NOT NULL,
        keterangan TEXT,
        waktu_kejadian TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_log_audit_kunci_waktu
      ON log_audit_kunci(waktu_kejadian DESC);
    ''');
  }

  Future<void> _buatTabelPerubahanMaster(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS log_perubahan_master (
        id TEXT PRIMARY KEY,
        entitas TEXT NOT NULL,
        id_entitas TEXT NOT NULL,
        nama_entitas_saat_itu TEXT NOT NULL,
        jenis_aksi TEXT NOT NULL,
        id_operator TEXT NOT NULL,
        nama_operator_saat_itu TEXT NOT NULL,
        ringkasan_perubahan TEXT NOT NULL,
        nilai_lama_json TEXT,
        nilai_baru_json TEXT,
        waktu_kejadian TEXT NOT NULL
      )
    ''');
  }

  Future<void> _buatIndeksAudit(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_buku_stok_waktu_id
      ON buku_besar_stok(waktu_kejadian DESC, id DESC);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_buku_stok_barang_waktu
      ON buku_besar_stok(id_barang, waktu_kejadian DESC);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_buku_stok_operator_waktu
      ON buku_besar_stok(id_operator, waktu_kejadian DESC);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_log_master_waktu
      ON log_perubahan_master(waktu_kejadian DESC);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_log_master_entitas_waktu
      ON log_perubahan_master(id_entitas, waktu_kejadian DESC);
    ''');
  }

  Future<void> _buatSkema(Database db) async {
    await db.execute('''
      CREATE TABLE operator_warung (
        id TEXT PRIMARY KEY,
        nama_panggilan TEXT NOT NULL,
        aktif_sekarang INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE master_barang (
        id TEXT PRIMARY KEY,
        kode_sku TEXT,
        nama_barang TEXT NOT NULL,
        kategori TEXT NOT NULL,
        jenis_barang TEXT NOT NULL,
        satuan_dasar TEXT NOT NULL,
        hpp_terakhir REAL,
        batas_stok_minimum REAL NOT NULL DEFAULT 5.0,
        stok_tercatat_dasar REAL NOT NULL DEFAULT 0.0,
        aktif INTEGER NOT NULL DEFAULT 1,
        dibuat_pada TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE satuan_barang (
        id TEXT PRIMARY KEY,
        id_barang TEXT NOT NULL REFERENCES master_barang(id) ON DELETE CASCADE,
        nama_satuan TEXT NOT NULL,
        rasio_ke_dasar REAL NOT NULL,
        harga_jual REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE buku_besar_stok (
        id TEXT PRIMARY KEY,
        id_barang TEXT NOT NULL REFERENCES master_barang(id),
        id_operator TEXT NOT NULL,
        nama_operator_saat_itu TEXT,
        jenis_kejadian TEXT NOT NULL,
        delta_satuan_dasar REAL NOT NULL,
        stok_sebelum REAL,
        stok_sesudah REAL,
        hpp_saat_kejadian REAL,
        id_referensi TEXT,
        catatan TEXT,
        waktu_kejadian TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE makro_transaksi (
        id TEXT PRIMARY KEY,
        label_tombol TEXT NOT NULL,
        id_barang TEXT NOT NULL REFERENCES master_barang(id) ON DELETE CASCADE,
        nama_satuan TEXT NOT NULL,
        kuantitas_bawaan REAL NOT NULL DEFAULT 1.0,
        harga_satuan_bawaan REAL NOT NULL,
        urutan_tampil INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE nota_penjualan (
        id TEXT PRIMARY KEY,
        id_operator TEXT NOT NULL,
        metode_bayar TEXT NOT NULL,
        id_pelanggan_kasbon TEXT,
        total_tagihan REAL NOT NULL,
        nominal_kasbon REAL NOT NULL DEFAULT 0.0,
        waktu_transaksi TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pelanggan_kasbon (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL,
        limit_kredit REAL NOT NULL DEFAULT 0.0,
        dibuat_pada TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE buku_besar_kasbon (
        id TEXT PRIMARY KEY,
        id_pelanggan TEXT NOT NULL REFERENCES pelanggan_kasbon(id),
        id_nota TEXT,
        jenis_mutasi TEXT NOT NULL,
        nominal REAL NOT NULL,
        keterangan TEXT NOT NULL,
        waktu_mutasi TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pengaturan_sistem (
        kunci TEXT PRIMARY KEY,
        nilai TEXT NOT NULL
      )
    ''');

    await _buatTabelAuditKunci(db);
    await _buatTabelPerubahanMaster(db);
    await _buatIndeksAudit(db);

    await db.execute('''
      CREATE INDEX idx_satuan_barang_id
      ON satuan_barang(id_barang);
    ''');
  }

  Future<void> _isiDataAwal(Database db) async {
    final sekarang = DateTime.now().toIso8601String();

    await db.insert('operator_warung', {
      'id': 'op_pemilik',
      'nama_panggilan': 'PEMILIK',
      'aktif_sekarang': 1,
    });
    await db.insert('operator_warung', {
      'id': 'op_keluarga_1',
      'nama_panggilan': 'KELUARGA 1',
      'aktif_sekarang': 0,
    });

    await db.insert('pengaturan_sistem', {'kunci': 'tema', 'nilai': 'Dark'});
    await db.insert('pengaturan_sistem', {'kunci': 'bahasa', 'nilai': 'BAHASA INDONESIA'});
    await db.insert('pengaturan_sistem', {'kunci': 'fitur_kasbon_aktif', 'nilai': 'true'});
    await db.insert('pengaturan_sistem', {'kunci': 'kunci_audit_aktif', 'nilai': 'false'});
    await db.insert('pengaturan_sistem', {'kunci': 'kunci_otomatis_latar', 'nilai': 'true'});
    await db.insert('pengaturan_sistem', {'kunci': 'timeout_kunci_menit', 'nilai': '3'});

    final barangAwal = [
      {
        'id': 'brg_kopi_sachet',
        'nama_barang': 'Kopi Sachet Instan',
        'kategori': 'Minuman',
        'jenis_barang': 'KEMASAN',
        'satuan_dasar': 'Pcs',
        'hpp_terakhir': 1250.0,
        'batas_stok_minimum': 20.0,
        'satuan': [
          {'id': 'sat_kopi_pcs', 'nama_satuan': 'Pcs', 'rasio_ke_dasar': 1.0, 'harga_jual': 1500.0},
          {'id': 'sat_kopi_rcg', 'nama_satuan': 'Renceng', 'rasio_ke_dasar': 10.0, 'harga_jual': 14000.0},
        ],
        'makro': {
          'id': 'mkr_1',
          'label_tombol': 'Kopi Sachet Instan (1 Renceng)',
          'nama_satuan': 'Renceng',
          'kuantitas_bawaan': 1.0,
          'harga_satuan_bawaan': 14000.0,
          'urutan_tampil': 1,
        },
      },
      {
        'id': 'brg_mie_instan',
        'nama_barang': 'Mie Instan Goreng',
        'kategori': 'Sembako',
        'jenis_barang': 'KEMASAN',
        'satuan_dasar': 'Bungkus',
        'hpp_terakhir': 2750.0,
        'batas_stok_minimum': 15.0,
        'satuan': [
          {'id': 'sat_mie_bks', 'nama_satuan': 'Bungkus', 'rasio_ke_dasar': 1.0, 'harga_jual': 3500.0},
          {'id': 'sat_mie_dus', 'nama_satuan': 'Dus', 'rasio_ke_dasar': 40.0, 'harga_jual': 118000.0},
        ],
        'makro': {
          'id': 'mkr_2',
          'label_tombol': 'Mie Instan Goreng (1 Dus)',
          'nama_satuan': 'Dus',
          'kuantitas_bawaan': 1.0,
          'harga_satuan_bawaan': 118000.0,
          'urutan_tampil': 2,
        },
      },
      {
        'id': 'brg_rokok_kretek',
        'nama_barang': 'Rokok Kretek Filter',
        'kategori': 'Rokok',
        'jenis_barang': 'KEMASAN',
        'satuan_dasar': 'Bungkus',
        'hpp_terakhir': 31500.0,
        'batas_stok_minimum': 10.0,
        'satuan': [
          {'id': 'sat_rkk_bks', 'nama_satuan': 'Bungkus', 'rasio_ke_dasar': 1.0, 'harga_jual': 35000.0},
          {'id': 'sat_rkk_slp', 'nama_satuan': 'Slop', 'rasio_ke_dasar': 10.0, 'harga_jual': 335000.0},
        ],
        'makro': {
          'id': 'mkr_3',
          'label_tombol': 'Rokok Kretek Filter (1 Bungkus)',
          'nama_satuan': 'Bungkus',
          'kuantitas_bawaan': 1.0,
          'harga_satuan_bawaan': 35000.0,
          'urutan_tampil': 3,
        },
      },
      {
        'id': 'brg_telur_ayam',
        'nama_barang': 'Telur Ayam Negeri',
        'kategori': 'Sembako',
        'jenis_barang': 'CURAH',
        'satuan_dasar': 'Gram',
        'hpp_terakhir': 25.0,
        'batas_stok_minimum': 3000.0,
        'satuan': [
          {'id': 'sat_tlr_kg', 'nama_satuan': 'Kg', 'rasio_ke_dasar': 1000.0, 'harga_jual': 28000.0},
          {'id': 'sat_tlr_grm', 'nama_satuan': 'Gram', 'rasio_ke_dasar': 1.0, 'harga_jual': 28.0},
        ],
        'makro': {
          'id': 'mkr_4',
          'label_tombol': 'Telur Ayam Negeri (1 Kg)',
          'nama_satuan': 'Kg',
          'kuantitas_bawaan': 1.0,
          'harga_satuan_bawaan': 28000.0,
          'urutan_tampil': 4,
        },
      },
      {
        'id': 'brg_beras_medium',
        'nama_barang': 'Beras Medium',
        'kategori': 'Sembako',
        'jenis_barang': 'CURAH',
        'satuan_dasar': 'Gram',
        'hpp_terakhir': null,
        'batas_stok_minimum': 5000.0,
        'satuan': [
          {'id': 'sat_brs_kg', 'nama_satuan': 'Kg', 'rasio_ke_dasar': 1000.0, 'harga_jual': 15000.0},
          {'id': 'sat_brs_grm', 'nama_satuan': 'Gram', 'rasio_ke_dasar': 1.0, 'harga_jual': 15.0},
        ],
        'makro': {
          'id': 'mkr_5',
          'label_tombol': 'Beras Medium (1 Kg)',
          'nama_satuan': 'Kg',
          'kuantitas_bawaan': 1.0,
          'harga_satuan_bawaan': 15000.0,
          'urutan_tampil': 5,
        },
      },
    ];

    for (final item in barangAwal) {
      await db.insert('master_barang', {
        'id': item['id'],
        'kode_sku': null,
        'nama_barang': item['nama_barang'],
        'kategori': item['kategori'],
        'jenis_barang': item['jenis_barang'],
        'satuan_dasar': item['satuan_dasar'],
        'hpp_terakhir': item['hpp_terakhir'],
        'batas_stok_minimum': item['batas_stok_minimum'],
        'stok_tercatat_dasar': 0.0,
        'aktif': 1,
        'dibuat_pada': sekarang,
      });

      final daftarSatuan = item['satuan'] as List;
      for (final s in daftarSatuan) {
        await db.insert('satuan_barang', {
          'id': s['id'],
          'id_barang': item['id'],
          'nama_satuan': s['nama_satuan'],
          'rasio_ke_dasar': s['rasio_ke_dasar'],
          'harga_jual': s['harga_jual'],
        });
      }

      final m = item['makro'] as Map<String, dynamic>;
      await db.insert('makro_transaksi', {
        'id': m['id'],
        'label_tombol': m['label_tombol'],
        'id_barang': item['id'],
        'nama_satuan': m['nama_satuan'],
        'kuantitas_bawaan': m['kuantitas_bawaan'],
        'harga_satuan_bawaan': m['harga_satuan_bawaan'],
        'urutan_tampil': m['urutan_tampil'],
      });
    }
  }
}