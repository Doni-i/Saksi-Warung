import 'package:flutter/material.dart';
import '../../domain/entitas/barang.dart';
import '../../domain/entitas/makro_transaksi.dart';
import '../../inti/tema/tema_saksi_warung.dart';
import '../pengendali/pengendali_inventaris.dart';
import '../pengendali/pengendali_transaksi.dart';
import '../widget/logo_saksi_warung.dart';

class LayarUtamaLaci extends StatefulWidget {
  final PengendaliTransaksi pengendaliTransaksi;
  final PengendaliInventaris pengendaliInventaris;
  final bool modeGelap;
  final VoidCallback? onKunciLayarAudit;
  final bool kunciAuditTersedia;

  const LayarUtamaLaci({
    super.key,
    required this.pengendaliTransaksi,
    required this.pengendaliInventaris,
    required this.modeGelap,
    this.onKunciLayarAudit,
    this.kunciAuditTersedia = false,
  });

  @override
  State<LayarUtamaLaci> createState() => _LayarUtamaLaciState();
}

class _LayarUtamaLaciState extends State<LayarUtamaLaci> {
  @override
  void initState() {
    super.initState();
    widget.pengendaliTransaksi.muatUlangData();
  }

  String _formatAngka(double nilai) {
    if (nilai == nilai.roundToDouble()) return nilai.toStringAsFixed(0);
    return nilai.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void _tampilkanAlertPeringatan(String pesan, {bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isWarning ? TemaSaksiWarung.merahPeringatan : TemaSaksiWarung.hijauAman,
        content: Text(pesan, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _eksekusiPintasanCepat(MakroTransaksi makro, Barang? barangTerkait) async {
    final namaItem = barangTerkait?.namaBarang ?? makro.labelTombol;
    final hasil = await widget.pengendaliTransaksi.catatPenjualan(
      idBarang: makro.idBarang,
      namaSatuan: makro.namaSatuan,
      kuantitas: makro.kuantitasBawaan,
      hargaSatuanOverride: makro.hargaSatuanBawaan,
      metodeBayar: 'TUNAI',
      catatan: 'Pintasan Laci: $namaItem (${_formatAngka(makro.kuantitasBawaan)} ${makro.namaSatuan})',
    );
    await widget.pengendaliInventaris.muatUlangInventaris();
    _tampilkanAlertPeringatan(
      hasil.pesan,
      isWarning: !hasil.berhasil || hasil.memicuAnomaliStokMinus,
    );
  }

  void _bukaDialogGantiOperator() {
    final pt = widget.pengendaliTransaksi;
    final ctrlNama = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.modeGelap ? TemaSaksiWarung.kartuGelap : TemaSaksiWarung.kanvasBersih,
        title: const Text(
          'PILIH PENJAGA WARUNG AKTIF',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...pt.daftarOperator.map(
                  (op) => ListTile(
                title: Text(op.namaPanggilan, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: op.aktifSekarang
                    ? const Icon(Icons.check_circle, color: TemaSaksiWarung.hijauAman)
                    : null,
                onTap: () async {
                  await pt.gantiOperator(op.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ),
            const Divider(),
            TextField(
              controller: ctrlNama,
              decoration: const InputDecoration(hintText: 'Tambah Penjaga Warung (misal: IBU)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('TUTUP')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TemaSaksiWarung.aksenOranye),
            onPressed: () async {
              if (ctrlNama.text.trim().isNotEmpty) {
                await pt.tambahOperator(ctrlNama.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('TAMBAH', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _bukaPengelolaPintasan({MakroTransaksi? makroUntukEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.modeGelap ? TemaSaksiWarung.kartuGelap : TemaSaksiWarung.kanvasBersih,
      builder: (sheetCtx) => SheetKelolaPintasan(
        pengendaliTransaksi: widget.pengendaliTransaksi,
        modeGelap: widget.modeGelap,
        makroAwalEdit: makroUntukEdit,
      ),
    );
  }

  void _bukaPanelInputManual() {
    final pt = widget.pengendaliTransaksi;
    if (pt.daftarBarang.isEmpty) {
      _tampilkanAlertPeringatan('Master barang di Inventaris masih kosong.', isWarning: true);
      return;
    }

    Barang barangDipilih = pt.daftarBarang.first;
    String satuanDipilih = barangDipilih.daftarSatuan.isNotEmpty
        ? barangDipilih.daftarSatuan.first.namaSatuan
        : barangDipilih.satuanDasar;
    final ctrlQty = TextEditingController(text: '1');
    final ctrlHarga = TextEditingController(
      text: barangDipilih.cariSatuan(satuanDipilih).hargaJual.toStringAsFixed(0),
    );
    String metodeBayar = 'TUNAI';
    String? idPelangganDipilih =
    pt.daftarPelangganKasbon.isNotEmpty ? pt.daftarPelangganKasbon.first.id : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.modeGelap ? TemaSaksiWarung.kartuGelap : TemaSaksiWarung.kanvasBersih,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final qty = double.tryParse(ctrlQty.text) ?? 0.0;
          final harga = double.tryParse(ctrlHarga.text) ?? 0.0;
          final total = qty * harga;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'CATAT ARUS KELUAR BARANG & KASBON',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: barangDipilih.id,
                    decoration: const InputDecoration(labelText: 'Pilih Barang dari Inventaris'),
                    items: pt.daftarBarang
                        .map(
                          (b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(
                          '${b.namaBarang} (Stok: ${_formatAngka(b.stokTercatatDasar)} ${b.satuanDasar})',
                        ),
                      ),
                    )
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setModalState(() {
                        barangDipilih = pt.daftarBarang.firstWhere((b) => b.id == val);
                        satuanDipilih = barangDipilih.daftarSatuan.isNotEmpty
                            ? barangDipilih.daftarSatuan.first.namaSatuan
                            : barangDipilih.satuanDasar;
                        ctrlHarga.text =
                            barangDipilih.cariSatuan(satuanDipilih).hargaJual.toStringAsFixed(0);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctrlQty,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Takaran / Kuantitas'),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(satuanDipilih),
                          initialValue: satuanDipilih,
                          decoration: const InputDecoration(labelText: 'Satuan'),
                          items: (barangDipilih.daftarSatuan.isNotEmpty
                              ? barangDipilih.daftarSatuan.map((s) => s.namaSatuan).toList()
                              : [barangDipilih.satuanDasar])
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setModalState(() {
                              satuanDipilih = val;
                              ctrlHarga.text =
                                  barangDipilih.cariSatuan(val).hargaJual.toStringAsFixed(0);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: ctrlHarga,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Harga per Satuan (Rp)'),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  if (pt.fiturKasbonAktif) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: ['TUNAI', 'KASBON'].map((m) {
                        final terpilih = metodeBayar == m;
                        return Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => metodeBayar = m),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              color: terpilih
                                  ? (m == 'KASBON'
                                  ? TemaSaksiWarung.aksenOranye
                                  : TemaSaksiWarung.hijauAman)
                                  : Colors.black26,
                              alignment: Alignment.center,
                              child: Text(
                                m,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (metodeBayar == 'KASBON')
                      DropdownButtonFormField<String>(
                        initialValue: idPelangganDipilih,
                        decoration: const InputDecoration(labelText: 'Buku Kasbon Pelanggan'),
                        items: pt.daftarPelangganKasbon
                            .map(
                              (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              '${p.nama} (Hutang: Rp ${p.totalHutangAktif.toStringAsFixed(0)})',
                            ),
                          ),
                        )
                            .toList(),
                        onChanged: (val) => setModalState(() => idPelangganDipilih = val),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'NILAI LACI: Rp ${total.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TemaSaksiWarung.aksenOranye,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () async {
                      final hasil = await pt.catatPenjualan(
                        idBarang: barangDipilih.id,
                        namaSatuan: satuanDipilih,
                        kuantitas: qty,
                        hargaSatuanOverride: harga,
                        metodeBayar: metodeBayar,
                        idPelangganKasbon: metodeBayar == 'KASBON' ? idPelangganDipilih : null,
                      );
                      await widget.pengendaliInventaris.muatUlangInventaris();
                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      _tampilkanAlertPeringatan(
                        hasil.pesan,
                        isWarning: !hasil.berhasil || hasil.memicuAnomaliStokMinus,
                      );
                    },
                    child: const Text(
                      'REKAM KE BUKU BESAR',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.pengendaliTransaksi,
      builder: (context, _) {
        final pt = widget.pengendaliTransaksi;
        if (pt.sedangMemuat) {
          return const Center(child: CircularProgressIndicator(color: TemaSaksiWarung.aksenOranye));
        }

        final jumlahAnomaliBarang =
            pt.daftarBarang.where((b) => b.apakahStokMinus || b.apakahStokMenipis).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: widget.modeGelap ? TemaSaksiWarung.kartuGelap : TemaSaksiWarung.latarObsidian,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const LogoSaksiWarung(ukuran: 26),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'SAKSI WARUNG',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (widget.kunciAuditTersedia && widget.onKunciLayarAudit != null) ...[
                        InkWell(
                          onTap: widget.onKunciLayarAudit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white30),
                              color: Colors.black26,
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock, size: 13, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'KUNCI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      InkWell(
                        onTap: _bukaDialogGantiOperator,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          color: TemaSaksiWarung.aksenOranye,
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 14, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                'JAGA: ${pt.operatorAktif?.namaPanggilan ?? 'PEMILIK'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'ARUS LACI HARI INI',
                    style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Rp ${pt.omzetHariIni.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${pt.daftarBarang.length} Item Aktif',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const Text('  •  ', style: TextStyle(color: Colors.grey)),
                      Text(
                        jumlahAnomaliBarang > 0
                            ? '$jumlahAnomaliBarang Perlu Cek Stok'
                            : 'Stok Terkendali',
                        style: TextStyle(
                          color: jumlahAnomaliBarang > 0
                              ? TemaSaksiWarung.aksenOranye
                              : TemaSaksiWarung.hijauAman,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PINTASAN LACI (1-KETUK)',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: TemaSaksiWarung.aksenOranye,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onPressed: () => _bukaPengelolaPintasan(),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text(
                      'ATUR PINTASAN',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.75,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: pt.daftarMakro.length + 1,
                itemBuilder: (ctx, idx) {
                  if (idx == pt.daftarMakro.length) {
                    return OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: TemaSaksiWarung.aksenOranye.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      onPressed: () => _bukaPengelolaPintasan(),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, color: TemaSaksiWarung.aksenOranye),
                          SizedBox(height: 4),
                          Text(
                            '+ TAMBAH PINTASAN',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: TemaSaksiWarung.aksenOranye,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final m = pt.daftarMakro[idx];
                  final barangTerkait = pt.cariBarangUntukMakro(m.idBarang);
                  final namaUtama = barangTerkait?.namaBarang ?? m.labelTombol;
                  final teksTakaran = '${_formatAngka(m.kuantitasBawaan)} ${m.namaSatuan}';
                  final stokMinus = barangTerkait?.apakahStokMinus ?? false;

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.modeGelap ? TemaSaksiWarung.kartuGelap : Colors.white,
                      foregroundColor:
                      widget.modeGelap ? Colors.white : TemaSaksiWarung.tintaMentah,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      side: BorderSide(
                        color: stokMinus
                            ? TemaSaksiWarung.merahPeringatan
                            : (widget.modeGelap ? Colors.white24 : TemaSaksiWarung.latarObsidian),
                        width: 1.5,
                      ),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    onPressed: () => _eksekusiPintasanCepat(m, barangTerkait),
                    onLongPress: () => _bukaPengelolaPintasan(makroUntukEdit: m),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          namaUtama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          color: TemaSaksiWarung.aksenOranye.withValues(alpha: 0.16),
                          child: Text(
                            teksTakaran,
                            style: const TextStyle(
                              color: TemaSaksiWarung.aksenOranye,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rp ${m.totalNominalBawaan.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: widget.modeGelap ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            GestureDetector(
              onTap: _bukaPanelInputManual,
              child: Container(
                height: 58,
                color: TemaSaksiWarung.aksenOranye,
                alignment: Alignment.center,
                child: const Text(
                  'CATAT KELUAR BARANG / KASBON',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SheetKelolaPintasan extends StatefulWidget {
  final PengendaliTransaksi pengendaliTransaksi;
  final bool modeGelap;
  final MakroTransaksi? makroAwalEdit;

  const SheetKelolaPintasan({
    super.key,
    required this.pengendaliTransaksi,
    required this.modeGelap,
    this.makroAwalEdit,
  });

  @override
  State<SheetKelolaPintasan> createState() => _SheetKelolaPintasanState();
}

class _SheetKelolaPintasanState extends State<SheetKelolaPintasan> {
  String? _idMakroSedangDiedit;
  late String _idBarangDipilih;
  late String _satuanDipilih;
  final _ctrlTakaran = TextEditingController(text: '1');
  final _ctrlHargaSatuan = TextEditingController();
  final _ctrlLabelKustom = TextEditingController();
  bool _labelDieditManual = false;

  @override
  void initState() {
    super.initState();
    final pt = widget.pengendaliTransaksi;
    if (widget.makroAwalEdit != null) {
      _muatKeForm(widget.makroAwalEdit!);
    } else if (pt.daftarBarang.isNotEmpty) {
      final barang = pt.daftarBarang.first;
      _idBarangDipilih = barang.id;
      _satuanDipilih = barang.daftarSatuan.isNotEmpty
          ? barang.daftarSatuan.first.namaSatuan
          : barang.satuanDasar;
      _ctrlHargaSatuan.text =
          barang.cariSatuan(_satuanDipilih).hargaJual.toStringAsFixed(0);
      _segarkanLabelOtomatis();
    } else {
      _idBarangDipilih = '';
      _satuanDipilih = '';
    }
  }

  @override
  void dispose() {
    _ctrlTakaran.dispose();
    _ctrlHargaSatuan.dispose();
    _ctrlLabelKustom.dispose();
    super.dispose();
  }

  String _formatAngka(double nilai) {
    if (nilai == nilai.roundToDouble()) return nilai.toStringAsFixed(0);
    return nilai.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void _muatKeForm(MakroTransaksi m) {
    _idMakroSedangDiedit = m.id;
    _idBarangDipilih = m.idBarang;
    _satuanDipilih = m.namaSatuan;
    _ctrlTakaran.text = _formatAngka(m.kuantitasBawaan);
    _ctrlHargaSatuan.text = m.hargaSatuanBawaan.toStringAsFixed(0);
    _ctrlLabelKustom.text = m.labelTombol;
    _labelDieditManual = true;
  }

  void _resetFormBaru() {
    final pt = widget.pengendaliTransaksi;
    if (pt.daftarBarang.isEmpty) return;
    final barang = pt.daftarBarang.first;
    setState(() {
      _idMakroSedangDiedit = null;
      _idBarangDipilih = barang.id;
      _satuanDipilih = barang.daftarSatuan.isNotEmpty
          ? barang.daftarSatuan.first.namaSatuan
          : barang.satuanDasar;
      _ctrlTakaran.text = '1';
      _ctrlHargaSatuan.text =
          barang.cariSatuan(_satuanDipilih).hargaJual.toStringAsFixed(0);
      _labelDieditManual = false;
      _segarkanLabelOtomatis();
    });
  }

  void _segarkanLabelOtomatis() {
    if (_labelDieditManual) return;
    final barang = widget.pengendaliTransaksi.cariBarangUntukMakro(_idBarangDipilih);
    if (barang == null) return;
    final qty = double.tryParse(_ctrlTakaran.text) ?? 1.0;
    _ctrlLabelKustom.text = '${barang.namaBarang} (${_formatAngka(qty)} $_satuanDipilih)';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.pengendaliTransaksi,
      builder: (context, _) {
        final pt = widget.pengendaliTransaksi;
        if (pt.daftarBarang.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Tambahkan master barang di tab Inventaris terlebih dahulu sebelum membuat pintasan.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        }

        final barangAktif = pt.cariBarangUntukMakro(_idBarangDipilih) ?? pt.daftarBarang.first;
        if (_idBarangDipilih != barangAktif.id) {
          _idBarangDipilih = barangAktif.id;
        }

        final daftarNamaSatuan = barangAktif.daftarSatuan.isNotEmpty
            ? barangAktif.daftarSatuan.map((s) => s.namaSatuan).toList()
            : [barangAktif.satuanDasar];

        if (!daftarNamaSatuan.contains(_satuanDipilih)) {
          _satuanDipilih = daftarNamaSatuan.first;
        }

        final qty = double.tryParse(_ctrlTakaran.text) ?? 0.0;
        final hargaSatuan = double.tryParse(_ctrlHargaSatuan.text) ?? 0.0;
        final totalTombol = qty * hargaSatuan;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 18,
            right: 18,
            top: 18,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'KONFIGURASI PINTASAN LACI',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Text(
                  'Setiap pintasan terhubung langsung ke master barang & takaran di Inventaris.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.modeGelap ? TemaSaksiWarung.panelGelap : Colors.white,
                    border: Border.all(color: TemaSaksiWarung.aksenOranye.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _idMakroSedangDiedit == null
                                ? 'TAMBAH PINTASAN BARU'
                                : 'UBAH PINTASAN TERPILIH',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: TemaSaksiWarung.aksenOranye,
                            ),
                          ),
                          if (_idMakroSedangDiedit != null)
                            TextButton(
                              onPressed: _resetFormBaru,
                              child: const Text('MODE TAMBAH BARU', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        key: ValueKey('brg_$_idBarangDipilih'),
                        initialValue: barangAktif.id,
                        decoration: const InputDecoration(labelText: 'Barang Inventaris'),
                        items: pt.daftarBarang
                            .map(
                              (b) => DropdownMenuItem(
                            value: b.id,
                            child: Text('${b.namaBarang} (${b.jenisBarang})'),
                          ),
                        )
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          final bBaru = pt.daftarBarang.firstWhere((b) => b.id == val);
                          final satBaru = bBaru.daftarSatuan.isNotEmpty
                              ? bBaru.daftarSatuan.first.namaSatuan
                              : bBaru.satuanDasar;
                          setState(() {
                            _idBarangDipilih = bBaru.id;
                            _satuanDipilih = satBaru;
                            _ctrlHargaSatuan.text =
                                bBaru.cariSatuan(satBaru).hargaJual.toStringAsFixed(0);
                            _segarkanLabelOtomatis();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ctrlTakaran,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Takaran (misal 0.5 / 1)'),
                              onChanged: (_) => setState(_segarkanLabelOtomatis),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('sat_${barangAktif.id}_$_satuanDipilih'),
                              initialValue: _satuanDipilih,
                              decoration: const InputDecoration(labelText: 'Satuan Ukur'),
                              items: daftarNamaSatuan
                                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                  .toList(),
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() {
                                  _satuanDipilih = val;
                                  _ctrlHargaSatuan.text = barangAktif
                                      .cariSatuan(val)
                                      .hargaJual
                                      .toStringAsFixed(0);
                                  _segarkanLabelOtomatis();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [0.25, 0.5, 1.0, 2.0, 5.0].map((preset) {
                          return ActionChip(
                            label: Text('${_formatAngka(preset)} $_satuanDipilih',
                                style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              setState(() {
                                _ctrlTakaran.text = _formatAngka(preset);
                                _segarkanLabelOtomatis();
                              });
                            },
                          );
                        }).toList(),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ctrlHargaSatuan,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Harga per $_satuanDipilih (Rp)',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _ctrlLabelKustom,
                              decoration: const InputDecoration(labelText: 'Label Pintasan'),
                              onChanged: (_) => _labelDieditManual = true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TemaSaksiWarung.aksenOranye,
                        ),
                        onPressed: () async {
                          final takaranValid = double.tryParse(_ctrlTakaran.text) ?? 0.0;
                          final hargaValid = double.tryParse(_ctrlHargaSatuan.text) ?? 0.0;
                          if (takaranValid <= 0) return;

                          final labelFinal = _ctrlLabelKustom.text.trim().isEmpty
                              ? '${barangAktif.namaBarang} (${_formatAngka(takaranValid)} $_satuanDipilih)'
                              : _ctrlLabelKustom.text.trim();

                          await pt.simpanAtauPerbaruiMakro(
                            idMakro: _idMakroSedangDiedit,
                            labelTombol: labelFinal,
                            idBarang: barangAktif.id,
                            namaSatuan: _satuanDipilih,
                            kuantitasBawaan: takaranValid,
                            hargaSatuanBawaan: hargaValid,
                          );
                          _resetFormBaru();
                        },
                        child: Text(
                          'SIMPAN PINTASAN (Rp ${totalTombol.toStringAsFixed(0)})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'DAFTAR PINTASAN AKTIF (${pt.daftarMakro.length})',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.builder(
                    itemCount: pt.daftarMakro.length,
                    itemBuilder: (ctx, idx) {
                      final m = pt.daftarMakro[idx];
                      final brg = pt.cariBarangUntukMakro(m.idBarang);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            brg?.namaBarang ?? m.labelTombol,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            'Takaran: ${_formatAngka(m.kuantitasBawaan)} ${m.namaSatuan} • Rp ${m.totalNominalBawaan.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (idx > 0)
                                IconButton(
                                  icon: const Icon(Icons.arrow_upward, size: 18),
                                  onPressed: () => pt.geserUrutanMakro(idx, idx - 1),
                                ),
                              if (idx < pt.daftarMakro.length - 1)
                                IconButton(
                                  icon: const Icon(Icons.arrow_downward, size: 18),
                                  onPressed: () => pt.geserUrutanMakro(idx, idx + 1),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18, color: TemaSaksiWarung.aksenOranye),
                                onPressed: () => setState(() => _muatKeForm(m)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18, color: TemaSaksiWarung.merahPeringatan),
                                onPressed: () async {
                                  await pt.hapusMakro(m.id);
                                  if (_idMakroSedangDiedit == m.id) {
                                    _resetFormBaru();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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