import 'package:flutter/material.dart';
import '../../domain/entitas/barang.dart';
import '../../domain/entitas/kejadian_stok.dart';
import '../../inti/tema/tema_saksi_warung.dart';
import '../pengendali/pengendali_audit.dart';
import '../pengendali/pengendali_inventaris.dart';
import '../pengendali/pengendali_transaksi.dart';
import '../widget/grafik_aktivitas_audit.dart';
import 'layar_jejak_audit.dart';

class LayarInventarisOpname extends StatefulWidget {
  final PengendaliInventaris pengendaliInventaris;
  final PengendaliAudit pengendaliAudit;
  final PengendaliTransaksi pengendaliTransaksi;
  final bool modeGelap;

  const LayarInventarisOpname({
    super.key,
    required this.pengendaliInventaris,
    required this.pengendaliAudit,
    required this.pengendaliTransaksi,
    required this.modeGelap,
  });

  @override
  State<LayarInventarisOpname> createState() => _LayarInventarisOpnameState();
}

class _LayarInventarisOpnameState extends State<LayarInventarisOpname> {
  @override
  void initState() {
    super.initState();
    widget.pengendaliInventaris.muatUlangInventaris();
  }

  Future<void> _bukaKartuStokBarang(Barang barang) async {
    final riwayat = await widget.pengendaliInventaris.ambilLogBarang(barang.id);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.modeGelap ? TemaSaksiWarung.kartuGelap : TemaSaksiWarung.kanvasBersih,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KARTU STOK: ${barang.namaBarang.toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                        Text(
                          'Saldo Saat Ini: ${barang.stokTercatatDasar.toStringAsFixed(1)} ${barang.satuanDasar}',
                          style: const TextStyle(
                            color: TemaSaksiWarung.aksenOranye,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LayarJejakAudit(
                            pengendaliAudit: widget.pengendaliAudit,
                            daftarOperator: widget.pengendaliTransaksi.daftarOperator,
                            modeGelap: widget.modeGelap,
                            idBarangFokus: barang.id,
                            namaBarangFokus: barang.namaBarang,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new, size: 15),
                    label: const Text('AUDIT LENGKAP', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                color: widget.modeGelap ? TemaSaksiWarung.panelGelap : Colors.white,
                child: GrafikSaldoKartuStok(
                  riwayatTerbaruKeLama: riwayat,
                  modeGelap: widget.modeGelap,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: riwayat.isEmpty
                    ? const Center(child: Text('Belum ada mutasi stok untuk barang ini.'))
                    : ListView.separated(
                  itemCount: riwayat.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final KejadianStok k = riwayat[i];
                    final l = k.waktuKejadian.toLocal();
                    final waktu =
                        '${l.day}/${l.month}/${l.year} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
                    final teksSaldo = (k.stokSebelum != null && k.stokSesudah != null)
                        ? '${k.stokSebelum!.toStringAsFixed(1)} → ${k.stokSesudah!.toStringAsFixed(1)} ${barang.satuanDasar}'
                        : '';

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${k.jenisKejadian} (${k.deltaSatuanDasar >= 0 ? '+' : ''}${k.deltaSatuanDasar.toStringAsFixed(1)} ${barang.satuanDasar})',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: k.adalahAnomali
                              ? TemaSaksiWarung.merahPeringatan
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        '${k.catatan ?? '-'}\n$teksSaldo • Penjaga: ${k.namaOperatorSaatItu ?? k.idOperator}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Text(
                        waktu,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _bukaDialogAksiBarang(Barang barang) {
    final pi = widget.pengendaliInventaris;
    final ctrlQty = TextEditingController(text: '1');
    final ctrlModalTotal = TextEditingController();
    final ctrlOpnameFisik = TextEditingController(text: barang.stokTercatatDasar.toStringAsFixed(0));
    String satuanDipilih = barang.daftarSatuan.isNotEmpty
        ? barang.daftarSatuan.first.namaSatuan
        : barang.satuanDasar;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.modeGelap ? TemaSaksiWarung.kartuGelap : TemaSaksiWarung.kanvasBersih,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                Text(
                  barang.namaBarang.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stok Buku: ${barang.stokTercatatDasar.toStringAsFixed(1)} ${barang.satuanDasar} | Anomali: ${barang.jumlahAnomaliTercatat}x',
                  style: TextStyle(
                    color: barang.apakahStokMinus
                        ? TemaSaksiWarung.merahPeringatan
                        : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _bukaKartuStokBarang(barang);
                        },
                        icon: const Icon(Icons.timeline, size: 16),
                        label: const Text(
                          'KARTU STOK',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _bukaDialogFormBarang(barangUntukEdit: barang);
                        },
                        icon: const Icon(Icons.edit, size: 16, color: TemaSaksiWarung.aksenOranye),
                        label: const Text(
                          'EDIT BARANG',
                          style: TextStyle(
                            color: TemaSaksiWarung.aksenOranye,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  '1. CATAT KULAKAN MASUK / AMBIL SENDIRI',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrlQty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Jumlah'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: satuanDipilih,
                        items: (barang.daftarSatuan.isNotEmpty
                            ? barang.daftarSatuan.map((s) => s.namaSatuan).toList()
                            : [barang.satuanDasar])
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) => setModalState(() => satuanDipilih = v!),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: ctrlModalTotal,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total Harga Beli Agen (Opsional - kosongkan jika belum tahu)',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: TemaSaksiWarung.hijauAman),
                        onPressed: () async {
                          final q = double.tryParse(ctrlQty.text) ?? 0.0;
                          final modal = double.tryParse(ctrlModalTotal.text);
                          final res = await pi.catatKulakanAtauKonsumsi(
                            idBarang: barang.id,
                            namaSatuan: satuanDipilih,
                            kuantitas: q,
                            totalHargaKulakan: modal,
                          );
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          if (mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(res.pesan)));
                          }
                        },
                        child: const Text('+ KULAKAN MASUK', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final q = double.tryParse(ctrlQty.text) ?? 0.0;
                          final res = await pi.catatKulakanAtauKonsumsi(
                            idBarang: barang.id,
                            namaSatuan: satuanDipilih,
                            kuantitas: q,
                            konsumsiPribadi: true,
                          );
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          if (mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(res.pesan)));
                          }
                        },
                        child: const Text('- AMBIL SENDIRI'),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                const Text(
                  '2. REKONSILIASI STOCK OPNAME (HITUNG FISIK RAK)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
                TextField(
                  controller: ctrlOpnameFisik,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Jumlah Fisik Nyata (${barang.satuanDasar})',
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: TemaSaksiWarung.aksenOranye),
                  onPressed: () async {
                    final fisik = double.tryParse(ctrlOpnameFisik.text) ?? -1.0;
                    final res = await pi.eksekusiOpname(
                      idBarang: barang.id,
                      jumlahFisikDasar: fisik,
                    );
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.pesan)));
                    }
                  },
                  child: const Text(
                    'REKAM SELISIH OPNAME',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _bukaDialogFormBarang({Barang? barangUntukEdit}) {
    final sedangEdit = barangUntukEdit != null;
    final satuanDasarAwal = barangUntukEdit?.daftarSatuan
        .where((s) => s.namaSatuan.toLowerCase() == barangUntukEdit.satuanDasar.toLowerCase())
        .firstOrNull;
    final satuanGrosirAwal = barangUntukEdit?.daftarSatuan
        .where((s) => s.namaSatuan.toLowerCase() != barangUntukEdit.satuanDasar.toLowerCase())
        .firstOrNull;

    final ctrlNama = TextEditingController(text: barangUntukEdit?.namaBarang ?? '');
    final ctrlKategori = TextEditingController(text: barangUntukEdit?.kategori ?? 'Umum');
    final ctrlDasar = TextEditingController(text: barangUntukEdit?.satuanDasar ?? 'Pcs');
    final ctrlHargaEcer = TextEditingController(
      text: satuanDasarAwal != null ? satuanDasarAwal.hargaJual.toStringAsFixed(0) : '',
    );
    final ctrlHpp = TextEditingController(
      text: barangUntukEdit?.hppTerakhir != null
          ? barangUntukEdit!.hppTerakhir!.toStringAsFixed(0)
          : '',
    );
    final ctrlBatasMin = TextEditingController(
      text: (barangUntukEdit?.batasStokMinimum ?? 5.0).toStringAsFixed(0),
    );
    final ctrlSatuanGrosir = TextEditingController(text: satuanGrosirAwal?.namaSatuan ?? '');
    final ctrlRasioGrosir = TextEditingController(
      text: satuanGrosirAwal != null ? satuanGrosirAwal.rasioKeDasar.toStringAsFixed(0) : '',
    );
    final ctrlHargaGrosir = TextEditingController(
      text: satuanGrosirAwal != null ? satuanGrosirAwal.hargaJual.toStringAsFixed(0) : '',
    );
    String jenis = barangUntukEdit?.jenisBarang ?? 'KEMASAN';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDlgState) => AlertDialog(
          backgroundColor: widget.modeGelap ? TemaSaksiWarung.kartuGelap : TemaSaksiWarung.kanvasBersih,
          title: Text(
            sedangEdit ? 'EDIT MASTER BARANG' : 'TAMBAH MASTER BARANG',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrlNama,
                  decoration: const InputDecoration(labelText: 'Nama Barang'),
                ),
                TextField(
                  controller: ctrlKategori,
                  decoration: const InputDecoration(labelText: 'Kategori (Sembako / Minuman / Rokok / Umum)'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: jenis,
                  decoration: const InputDecoration(labelText: 'Tipe Barang'),
                  items: const [
                    DropdownMenuItem(value: 'KEMASAN', child: Text('Kemasan (Dus/Renceng/Pcs)')),
                    DropdownMenuItem(value: 'CURAH', child: Text('Curah / Timbang (Kg/Gram/Liter)')),
                  ],
                  onChanged: (v) => setDlgState(() => jenis = v!),
                ),
                TextField(
                  controller: ctrlDasar,
                  decoration: const InputDecoration(
                    labelText: 'Satuan Dasar Terkecil (Pcs/Bungkus/Gram)',
                  ),
                ),
                TextField(
                  controller: ctrlHargaEcer,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Harga Jual Satuan Dasar (Rp)'),
                ),
                TextField(
                  controller: ctrlHpp,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'HPP Modal Dasar (Opsional)'),
                ),
                TextField(
                  controller: ctrlBatasMin,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Batas Stok Minimum (dalam satuan dasar)',
                  ),
                ),
                const Divider(),
                TextField(
                  controller: ctrlSatuanGrosir,
                  decoration: const InputDecoration(
                    labelText: 'Satuan Grosir (misal: Dus / Renceng / Kg)',
                  ),
                ),
                TextField(
                  controller: ctrlRasioGrosir,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Isi per Satuan Grosir (misal: 40 atau 1000)',
                  ),
                ),
                TextField(
                  controller: ctrlHargaGrosir,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Harga Jual Grosir (Rp)'),
                ),
                if (sedangEdit) ...[
                  const Divider(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.archive_outlined,
                        size: 18,
                        color: TemaSaksiWarung.merahPeringatan,
                      ),
                      label: const Text(
                        'NONAKTIFKAN / ARSIPKAN BARANG',
                        style: TextStyle(
                          color: TemaSaksiWarung.merahPeringatan,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      onPressed: () async {
                        await widget.pengendaliInventaris.nonaktifkanBarang(barangUntukEdit.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${barangUntukEdit.namaBarang} diarsipkan dari daftar aktif.'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('BATAL')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: TemaSaksiWarung.aksenOranye),
              onPressed: () async {
                if (ctrlNama.text.trim().isEmpty) return;
                final satuanDasarFinal =
                ctrlDasar.text.trim().isEmpty ? 'Pcs' : ctrlDasar.text.trim();
                final batasMinFinal = double.tryParse(ctrlBatasMin.text) ?? 5.0;
                final hargaDasarFinal = double.tryParse(ctrlHargaEcer.text) ?? 0.0;

                if (sedangEdit) {
                  await widget.pengendaliInventaris.perbaruiBarangMaster(
                    barangLama: barangUntukEdit,
                    namaBarang: ctrlNama.text,
                    kategori: ctrlKategori.text,
                    jenisBarang: jenis,
                    satuanDasar: satuanDasarFinal,
                    hppTerakhir: double.tryParse(ctrlHpp.text),
                    batasStokMinimum: batasMinFinal,
                    hargaJualDasar: hargaDasarFinal,
                    namaSatuanGrosir: ctrlSatuanGrosir.text,
                    rasioSatuanGrosir: double.tryParse(ctrlRasioGrosir.text),
                    hargaJualGrosir: double.tryParse(ctrlHargaGrosir.text),
                  );
                } else {
                  await widget.pengendaliInventaris.tambahBarangMaster(
                    namaBarang: ctrlNama.text,
                    kategori: ctrlKategori.text,
                    jenisBarang: jenis,
                    satuanDasar: satuanDasarFinal,
                    hppTerakhir: double.tryParse(ctrlHpp.text),
                    batasStokMinimum: batasMinFinal,
                    hargaJualDasar: hargaDasarFinal,
                    namaSatuanGrosir: ctrlSatuanGrosir.text,
                    rasioSatuanGrosir: double.tryParse(ctrlRasioGrosir.text),
                    hargaJualGrosir: double.tryParse(ctrlHargaGrosir.text),
                  );
                }

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        sedangEdit
                            ? 'Perubahan ${ctrlNama.text.trim()} disimpan.'
                            : 'Master barang ${ctrlNama.text.trim()} ditambahkan.',
                      ),
                    ),
                  );
                }
              },
              child: Text(
                sedangEdit ? 'SIMPAN PERUBAHAN' : 'SIMPAN',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.pengendaliInventaris,
      builder: (context, _) {
        final pi = widget.pengendaliInventaris;
        if (pi.sedangMemuat) {
          return const Center(child: CircularProgressIndicator(color: TemaSaksiWarung.aksenOranye));
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: widget.modeGelap ? TemaSaksiWarung.kartuGelap : TemaSaksiWarung.latarObsidian,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BUKU BESAR INVENTARIS & OPNAME',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: TemaSaksiWarung.aksenOranye),
                    onPressed: () => _bukaDialogFormBarang(),
                    child: const Text(
                      '+ BARANG',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            if (pi.daftarAnomali.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: TemaSaksiWarung.merahPeringatan.withValues(alpha: 0.15),
                child: Text(
                  'JEJAK AUDIT ANOMALI: ${pi.daftarAnomali.length} kejadian stok minus / selisih opname tercatat.',
                  style: const TextStyle(
                    color: TemaSaksiWarung.merahPeringatan,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: pi.daftarBarang.length,
                itemBuilder: (ctx, idx) {
                  final b = pi.daftarBarang[idx];
                  final ringkasanSatuan = b.daftarSatuan
                      .map((s) => '${s.namaSatuan}: Rp ${s.hargaJual.toStringAsFixed(0)}')
                      .join(' • ');

                  return ListTile(
                    onTap: () => _bukaDialogAksiBarang(b),
                    title: Text(b.namaBarang, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(
                      '${b.kategori} • ${b.jenisBarang} | HPP: ${b.hppTerakhir != null ? 'Rp ${b.hppTerakhir!.toStringAsFixed(0)}' : 'Belum diset'}'
                          '${ringkasanSatuan.isNotEmpty ? '\n$ringkasanSatuan' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    isThreeLine: ringkasanSatuan.isNotEmpty,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${b.stokTercatatDasar.toStringAsFixed(0)} ${b.satuanDasar}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: b.apakahStokMinus
                                    ? TemaSaksiWarung.merahPeringatan
                                    : (b.apakahStokMenipis
                                    ? TemaSaksiWarung.aksenOranye
                                    : TemaSaksiWarung.hijauAman),
                              ),
                            ),
                            if (b.jumlahAnomaliTercatat > 0)
                              Text(
                                '${b.jumlahAnomaliTercatat}x Anomali',
                                style: const TextStyle(
                                  color: TemaSaksiWarung.merahPeringatan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Edit Master Barang',
                          icon: const Icon(Icons.edit, size: 19, color: TemaSaksiWarung.aksenOranye),
                          onPressed: () => _bukaDialogFormBarang(barangUntukEdit: b),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}