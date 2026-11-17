import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'data/repositori/implementasi_repositori_audit.dart';
import 'data/repositori/implementasi_repositori_inventaris.dart';
import 'data/repositori/implementasi_repositori_spk.dart';
import 'data/repositori/implementasi_repositori_transaksi.dart';
import 'domain/kasus_penggunaan/catat_stok_masuk.dart';
import 'domain/kasus_penggunaan/eksekusi_transaksi_makro.dart';
import 'domain/kasus_penggunaan/hitung_prioritas_kulakan.dart';
import 'domain/kasus_penggunaan/rekonsiliasi_stok_opname.dart';
import 'domain/spk/kalkulator_bobot_ahp.dart';
import 'domain/spk/mesin_peringkat_topsis.dart';
import 'inti/basis_data/pengelola_basis_data.dart';
import 'inti/keamanan/pengelola_kunci_audit.dart';
import 'inti/tema/tema_saksi_warung.dart';
import 'presentasi/layar/layar_inventaris_opname.dart';
import 'presentasi/layar/layar_kunci_audit.dart';
import 'presentasi/layar/layar_pengaturan.dart';
import 'presentasi/layar/layar_spk_kulakan.dart';
import 'presentasi/layar/layar_utama_laci.dart';
import 'presentasi/pengendali/pengendali_audit.dart';
import 'presentasi/pengendali/pengendali_inventaris.dart';
import 'presentasi/pengendali/pengendali_spk.dart';
import 'presentasi/pengendali/pengendali_transaksi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final pengelolaDb = PengelolaBasisData.instansi;
  await pengelolaDb.inisialisasi();

  final repoInventaris = ImplementasiRepositoriInventaris(pengelolaDb);
  final repoTransaksi = ImplementasiRepositoriTransaksi(pengelolaDb);
  final repoSpk = ImplementasiRepositoriSpk(pengelolaDb);
  final repoAudit = ImplementasiRepositoriAudit(pengelolaDb);

  final eksekusiTransaksi = EksekusiTransaksiMakro(repoInventaris, repoTransaksi);
  final catatStokMasuk = CatatStokMasuk(repoInventaris, repoTransaksi);
  final rekonsiliasiOpname = RekonsiliasiStokOpname(repoInventaris, repoTransaksi);
  final hitungPrioritas = HitungPrioritasKulakan(
    repoSpk,
    KalkulatorBobotAhp(),
    MesinPeringkatTopsis(),
  );

  final pengendaliTransaksi = PengendaliTransaksi(
    repoInventaris,
    repoTransaksi,
    eksekusiTransaksi,
  );
  final pengendaliInventaris = PengendaliInventaris(
    repoInventaris,
    catatStokMasuk,
    rekonsiliasiOpname,
  );
  final pengendaliSpk = PengendaliSpk(repoSpk, hitungPrioritas);
  final pengendaliAudit = PengendaliAudit(repoAudit);

  final operatorAwal = await repoTransaksi.ambilOperatorAktif();
  final pengelolaKunci = PengelolaKunciAudit();
  await pengelolaKunci.inisialisasi(idOperatorAwal: operatorAwal.id);

  runApp(
    SaksiWarungApp(
      pengendaliTransaksi: pengendaliTransaksi,
      pengendaliInventaris: pengendaliInventaris,
      pengendaliSpk: pengendaliSpk,
      pengendaliAudit: pengendaliAudit,
      pengelolaKunci: pengelolaKunci,
    ),
  );
}

class SaksiWarungApp extends StatefulWidget {
  final PengendaliTransaksi pengendaliTransaksi;
  final PengendaliInventaris pengendaliInventaris;
  final PengendaliSpk pengendaliSpk;
  final PengendaliAudit pengendaliAudit;
  final PengelolaKunciAudit pengelolaKunci;

  const SaksiWarungApp({
    super.key,
    required this.pengendaliTransaksi,
    required this.pengendaliInventaris,
    required this.pengendaliSpk,
    required this.pengendaliAudit,
    required this.pengelolaKunci,
  });

  @override
  State<SaksiWarungApp> createState() => _SaksiWarungAppState();
}

class _SaksiWarungAppState extends State<SaksiWarungApp> with WidgetsBindingObserver {
  bool _modeGelap = true;
  int _indeksTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _muatPreferensiTema();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final idOp = widget.pengendaliTransaksi.operatorAktif?.id ?? 'op_pemilik';
    widget.pengelolaKunci.tanganiPerubahanLifecycle(state, idOperatorAktif: idOp);
  }

  Future<void> _muatPreferensiTema() async {
    final db = await PengelolaBasisData.instansi.basisData;
    final rows = await db.query('pengaturan_sistem', where: 'kunci = ?', whereArgs: ['tema']);
    if (rows.isNotEmpty && mounted) {
      setState(() => _modeGelap = rows.first['nilai'] == 'Dark');
    }
  }

  Future<void> _ubahTema(bool gelap) async {
    setState(() => _modeGelap = gelap);
    final db = await PengelolaBasisData.instansi.basisData;
    await db.insert(
      'pengaturan_sistem',
      {'kunci': 'tema', 'nilai': gelap ? 'Dark' : 'Light'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.pengelolaKunci, widget.pengendaliTransaksi]),
      builder: (context, _) {
        final pk = widget.pengelolaKunci;
        final pt = widget.pengendaliTransaksi;
        final idOpAktif = pt.operatorAktif?.id ?? 'op_pemilik';

        final layarAktif = [
          LayarUtamaLaci(
            pengendaliTransaksi: pt,
            pengendaliInventaris: widget.pengendaliInventaris,
            modeGelap: _modeGelap,
            kunciAuditTersedia: pk.kunciAuditAktif && pk.pinSudahDiatur,
            onKunciLayarAudit: () {
              pk.kunciSekarang(
                idOperator: idOpAktif,
                jenisAktivitas: 'DIKUNCI_MANUAL',
                keterangan: 'Dikunci cepat dari layar Laci Lapak',
              );
            },
          ),
          LayarInventarisOpname(
            pengendaliInventaris: widget.pengendaliInventaris,
            pengendaliAudit: widget.pengendaliAudit,
            pengendaliTransaksi: pt,
            modeGelap: _modeGelap,
          ),
          LayarSpkKulakan(
            pengendaliSpk: widget.pengendaliSpk,
            modeGelap: _modeGelap,
          ),
          LayarPengaturan(
            pengendaliTransaksi: pt,
            pengendaliAudit: widget.pengendaliAudit,
            pengelolaKunci: pk,
            modeGelap: _modeGelap,
            onUbahTema: _ubahTema,
          ),
        ];

        return Listener(
          onPointerDown: (_) => pk.catatInteraksiPengguna(idOperatorAktif: idOpAktif),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Saksi Warung',
            theme: ThemeData(
              brightness: _modeGelap ? Brightness.dark : Brightness.light,
              scaffoldBackgroundColor:
              _modeGelap ? TemaSaksiWarung.panelGelap : TemaSaksiWarung.kanvasBersih,
            ),
            home: Stack(
              children: [
                Scaffold(
                  body: SafeArea(child: layarAktif[_indeksTab]),
                  bottomNavigationBar: BottomNavigationBar(
                    currentIndex: _indeksTab,
                    type: BottomNavigationBarType.fixed,
                    backgroundColor:
                    _modeGelap ? TemaSaksiWarung.kartuGelap : TemaSaksiWarung.latarObsidian,
                    selectedItemColor: TemaSaksiWarung.aksenOranye,
                    unselectedItemColor: Colors.grey,
                    onTap: (i) => setState(() => _indeksTab = i),
                    items: const [
                      BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Laci Lapak'),
                      BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Inventaris'),
                      BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'SPK Kulakan'),
                      BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Pengaturan'),
                    ],
                  ),
                ),
                if (pk.sedangTerkunci)
                  Positioned.fill(
                    child: LayarKunciAudit(
                      pengelolaKunci: pk,
                      daftarOperator: pt.daftarOperator,
                      operatorAktif: pt.operatorAktif,
                      onGantiOperator: pt.gantiOperator,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}