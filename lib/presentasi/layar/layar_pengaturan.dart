import 'package:flutter/material.dart';
import '../../inti/basis_data/pengelola_basis_data.dart';
import '../../inti/keamanan/layanan_cadangan_lokal.dart';
import '../../inti/keamanan/pengelola_kunci_audit.dart';
import '../../inti/tema/tema_saksi_warung.dart';
import '../pengendali/pengendali_audit.dart';
import '../pengendali/pengendali_transaksi.dart';
import 'layar_jejak_audit.dart';
import 'layar_utama_laci.dart';

class LayarPengaturan extends StatefulWidget {
  final PengendaliTransaksi pengendaliTransaksi;
  final PengendaliAudit pengendaliAudit;
  final PengelolaKunciAudit pengelolaKunci;
  final bool modeGelap;
  final ValueChanged<bool> onUbahTema;

  const LayarPengaturan({
    super.key,
    required this.pengendaliTransaksi,
    required this.pengendaliAudit,
    required this.pengelolaKunci,
    required this.modeGelap,
    required this.onUbahTema,
  });

  @override
  State<LayarPengaturan> createState() => _LayarPengaturanState();
}

class _LayarPengaturanState extends State<LayarPengaturan> {
  final _layananCadangan = LayananCadanganLokal();
  final _ctrlJalurImpor = TextEditingController();
  String? _statusCadangan;

  @override
  void initState() {
    super.initState();
    widget.pengendaliAudit.muatRingkasanAwal();
  }

  @override
  void dispose() {
    _ctrlJalurImpor.dispose();
    super.dispose();
  }

  void _bukaDialogAturPinAudit() {
    final ctrlPin = TextEditingController();
    final ctrlKonfirmasi = TextEditingController();
    String? galat;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDlgState) => AlertDialog(
          backgroundColor: widget.modeGelap ? TemaSaksiWarung.kartuGelap : TemaSaksiWarung.kanvasBersih,
          title: const Text(
            'ATUR PIN KUNCI LAYAR AUDIT',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrlPin,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'PIN Baru (4–6 digit angka)'),
              ),
              TextField(
                controller: ctrlKonfirmasi,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Ulangi PIN Baru'),
              ),
              if (galat != null)
                Text(
                  galat!,
                  style: const TextStyle(
                    color: TemaSaksiWarung.merahPeringatan,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('BATAL')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: TemaSaksiWarung.aksenOranye),
              onPressed: () async {
                if (ctrlPin.text != ctrlKonfirmasi.text) {
                  setDlgState(() => galat = 'Konfirmasi PIN tidak cocok.');
                  return;
                }
                final idOp = widget.pengendaliTransaksi.operatorAktif?.id ?? 'op_pemilik';
                final res = await widget.pengelolaKunci.aturPinBaru(
                  pinBaru: ctrlPin.text,
                  idOperator: idOp,
                );
                if (!res.berhasil) {
                  setDlgState(() => galat = res.pesan);
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.pesan)));
                }
              },
              child: const Text('SIMPAN PIN', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _bukaDialogNonaktifkanKunci() {
    final ctrlPin = TextEditingController();
    String? galat;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDlgState) => AlertDialog(
          backgroundColor: widget.modeGelap ? TemaSaksiWarung.kartuGelap : TemaSaksiWarung.kanvasBersih,
          title: const Text(
            'NONAKTIFKAN KUNCI AUDIT',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrlPin,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Masukkan PIN Audit Saat Ini'),
              ),
              if (galat != null)
                Text(
                  galat!,
                  style: const TextStyle(
                    color: TemaSaksiWarung.merahPeringatan,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('BATAL')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: TemaSaksiWarung.merahPeringatan),
              onPressed: () async {
                final idOp = widget.pengendaliTransaksi.operatorAktif?.id ?? 'op_pemilik';
                final res = await widget.pengelolaKunci.nonaktifkanKunciDenganPin(
                  pinVerifikasi: ctrlPin.text,
                  idOperator: idOp,
                );
                if (!res.berhasil) {
                  setDlgState(() => galat = res.pesan);
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.pesan)));
                }
              },
              child: const Text('NONAKTIFKAN', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.pengendaliTransaksi,
        widget.pengelolaKunci,
        widget.pengendaliAudit,
      ]),
      builder: (context, _) {
        final pt = widget.pengendaliTransaksi;
        final pk = widget.pengelolaKunci;
        final pa = widget.pengendaliAudit;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'PENGATURAN SISTEM & KEAMANAN AUDIT',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 12),
            // Dedicated Audit Trail + Interactive Chart Launcher Card
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LayarJejakAudit(
                      pengendaliAudit: pa,
                      daftarOperator: pt.daftarOperator,
                      modeGelap: widget.modeGelap,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.modeGelap ? TemaSaksiWarung.kartuGelap : Colors.white,
                  border: Border.all(color: TemaSaksiWarung.aksenOranye, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart, color: TemaSaksiWarung.aksenOranye, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BUKA JEJAK AUDIT & GRAFIK BUKU BESAR',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            pa.jumlahPerhatian7Hari > 0
                                ? '${pa.jumlahPerhatian7Hari} anomali / perubahan harga 7 hari terakhir'
                                : 'Riwayat mutasi stok, edit harga & keamanan shift',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: pa.jumlahPerhatian7Hari > 0
                                  ? TemaSaksiWarung.aksenOranye
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Mode Gelap (Dark Theme)', style: TextStyle(fontWeight: FontWeight.bold)),
              value: widget.modeGelap,
              activeThumbColor: TemaSaksiWarung.aksenOranye,
              onChanged: widget.onUbahTema,
            ),
            SwitchListTile(
              title: const Text('Aktifkan Buku Kasbon', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Tampilkan opsi metode bayar Kasbon pada Laci Lapak'),
              value: pt.fiturKasbonAktif,
              activeThumbColor: TemaSaksiWarung.aksenOranye,
              onChanged: (v) => pt.setelStatusFiturKasbon(v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Kelola Pintasan Laci (1-Ketuk)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${pt.daftarMakro.length} tombol pintasan aktif'),
              trailing: OutlinedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: widget.modeGelap
                        ? TemaSaksiWarung.kartuGelap
                        : TemaSaksiWarung.kanvasBersih,
                    builder: (_) => SheetKelolaPintasan(
                      pengendaliTransaksi: pt,
                      modeGelap: widget.modeGelap,
                    ),
                  );
                },
                child: const Text('ATUR'),
              ),
            ),
            const Divider(height: 32),
            const Text(
              'KUNCI LAYAR AUDIT (INTEGRITAS SHIFT)',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              pk.kunciAuditAktif && pk.pinSudahDiatur
                  ? 'Status: AKTIF — setiap buka kunci & pergantian shift tercatat ke log audit.'
                  : 'Status: NONAKTIF — atur PIN 4–6 digit untuk mengunci layar saat lapak ditinggal.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: pk.kunciAuditAktif && pk.pinSudahDiatur
                    ? TemaSaksiWarung.hijauAman
                    : Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: TemaSaksiWarung.aksenOranye),
                    icon: const Icon(Icons.pin, color: Colors.white, size: 18),
                    label: Text(
                      pk.pinSudahDiatur ? 'UBAH PIN AUDIT' : 'AKTIFKAN PIN AUDIT',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _bukaDialogAturPinAudit,
                  ),
                ),
                if (pk.kunciAuditAktif && pk.pinSudahDiatur) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _bukaDialogNonaktifkanKunci,
                    child: const Text('MATIKAN'),
                  ),
                ],
              ],
            ),
            if (pk.kunciAuditAktif && pk.pinSudahDiatur) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.lock),
                label: const Text('KUNCI LAYAR SEKARANG'),
                onPressed: () {
                  final idOp = pt.operatorAktif?.id ?? 'op_pemilik';
                  pk.kunciSekarang(
                    idOperator: idOp,
                    jenisAktivitas: 'DIKUNCI_MANUAL',
                    keterangan: 'Dikunci manual dari menu Pengaturan',
                  );
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kunci Otomatis Saat Keluar Aplikasi / Layar Mati'),
                value: pk.kunciSaatLatarBelakang,
                activeThumbColor: TemaSaksiWarung.aksenOranye,
                onChanged: pk.setelKunciLatarBelakang,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kunci Otomatis Jika Diam (Idle):', style: TextStyle(fontSize: 13)),
                  DropdownButton<int>(
                    value: pk.timeoutIdleMenit,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Mati')),
                      DropdownMenuItem(value: 1, child: Text('1 Menit')),
                      DropdownMenuItem(value: 3, child: Text('3 Menit')),
                      DropdownMenuItem(value: 5, child: Text('5 Menit')),
                    ],
                    onChanged: (v) {
                      if (v != null) pk.setelTimeoutIdle(v);
                    },
                  ),
                ],
              ),
            ],
            const Divider(height: 32),
            const Text(
              'CADANGAN TERENKRIPSI AES-256 (100% LURING)',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Lokasi DB: ${PengelolaBasisData.instansi.jalurBerkasAktif}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: TemaSaksiWarung.hijauAman),
              icon: const Icon(Icons.lock, color: Colors.white),
              label: const Text(
                'EKSPOR CADANGAN TERENKRIPSI (.ENC)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                final res = await _layananCadangan.eksporCadanganTerenkripsi();
                setState(() {
                  _statusCadangan = res.berhasil ? '${res.pesan}\n${res.jalurHasil}' : res.pesan;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrlJalurImpor,
              decoration: const InputDecoration(
                labelText: 'Jalur Lengkap Berkas .enc untuk Pemulihan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('PULIHKAN DARI BERKAS .ENC'),
              onPressed: () async {
                if (_ctrlJalurImpor.text.trim().isEmpty) return;
                final res = await _layananCadangan.imporCadanganTerenkripsi(
                  jalurBerkasEnc: _ctrlJalurImpor.text.trim(),
                );
                await pt.muatUlangData();
                await pa.muatRingkasanAwal();
                await pk.inisialisasi(idOperatorAwal: pt.operatorAktif?.id);
                setState(() => _statusCadangan = res.pesan);
              },
            ),
            if (_statusCadangan != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                _statusCadangan!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                ),
              ),
            ],
            const Divider(height: 32),
            const Text(
              'TENTANG SAKSI WARUNG',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sistem pencatatan inventaris, makro transaksi, audit shift, dan pendukung keputusan (AHP + TOPSIS) berbasis buku besar kejadian (event-driven ledger) luring mandiri.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        );
      },
    );
  }
}