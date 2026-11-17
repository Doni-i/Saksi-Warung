import 'package:flutter/material.dart';
import '../../domain/entitas/akun_kasbon.dart';
import '../../domain/entitas/entri_audit.dart';
import '../../inti/tema/tema_saksi_warung.dart';
import '../pengendali/pengendali_audit.dart';
import '../widget/grafik_aktivitas_audit.dart';

class LayarJejakAudit extends StatefulWidget {
  final PengendaliAudit pengendaliAudit;
  final List<OperatorWarung> daftarOperator;
  final bool modeGelap;
  final String? idBarangFokus;
  final String? namaBarangFokus;

  const LayarJejakAudit({
    super.key,
    required this.pengendaliAudit,
    required this.daftarOperator,
    required this.modeGelap,
    this.idBarangFokus,
    this.namaBarangFokus,
  });

  @override
  State<LayarJejakAudit> createState() => _LayarJejakAuditState();
}

class _LayarJejakAuditState extends State<LayarJejakAudit> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.pengendaliAudit.muatRingkasanAwal(idBarangAwal: widget.idBarangFokus);
    _scrollController.addListener(_saatScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_saatScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _saatScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.pengendaliAudit.muatHalamanBerikutnya();
    }
  }

  String _formatWaktu(DateTime dt) {
    final l = dt.toLocal();
    final d = l.day.toString().padLeft(2, '0');
    final m = l.month.toString().padLeft(2, '0');
    final y = l.year;
    final jam = l.hour.toString().padLeft(2, '0');
    final mnt = l.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $jam:$mnt';
  }

  Color _warnaKategori(EntriJejakAudit item) {
    if (item.butuhPerhatian && item.kategori != KategoriAudit.perubahanMaster) {
      return TemaSaksiWarung.merahPeringatan;
    }
    switch (item.kategori) {
      case KategoriAudit.perubahanMaster:
        return TemaSaksiWarung.aksenOranye;
      case KategoriAudit.keamananKunci:
        return Colors.blueAccent;
      case KategoriAudit.anomaliDanOpname:
        return TemaSaksiWarung.merahPeringatan;
      case KategoriAudit.stokDanPenjualan:
      case KategoriAudit.semua:
        return TemaSaksiWarung.hijauAman;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
        widget.modeGelap ? TemaSaksiWarung.kartuGelap : TemaSaksiWarung.latarObsidian,
        foregroundColor: Colors.white,
        title: Text(
          widget.namaBarangFokus != null
              ? 'JEJAK AUDIT: ${widget.namaBarangFokus!.toUpperCase()}'
              : 'JEJAK AUDIT & INTEGRITAS BUKU BESAR',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset Filter',
            icon: const Icon(Icons.filter_alt_off),
            onPressed: () => widget.pengendaliAudit.resetSemuaFilter(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.pengendaliAudit,
        builder: (context, _) {
          final pa = widget.pengendaliAudit;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Interactive Activity & Anomaly Chart
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                color: widget.modeGelap ? TemaSaksiWarung.kartuGelap : Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'AKTIVITAS & ANOMALI HARIAN',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                        Row(
                          children: [7, 30, 90].map((hari) {
                            final aktif = pa.rentangHariGrafik == hari;
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: InkWell(
                                onTap: () => pa.ubahRentangGrafik(hari),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  color: aktif
                                      ? TemaSaksiWarung.aksenOranye
                                      : Colors.black26,
                                  child: Text(
                                    '${hari}H',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GrafikAktivitasAudit(
                      dataHarian: pa.dataGrafikHarian,
                      tanggalTerpilihIso: pa.filterTanggalIso,
                      onPilihTanggal: pa.pilihTanggalGrafik,
                      modeGelap: widget.modeGelap,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            _LegendaDot(warna: TemaSaksiWarung.hijauAman, label: 'Normal'),
                            SizedBox(width: 10),
                            _LegendaDot(warna: TemaSaksiWarung.aksenOranye, label: 'Edit Harga/Master'),
                            SizedBox(width: 10),
                            _LegendaDot(warna: TemaSaksiWarung.merahPeringatan, label: 'Anomali/Opname'),
                          ],
                        ),
                        if (pa.filterTanggalIso != null)
                          InkWell(
                            onTap: () => pa.pilihTanggalGrafik(null),
                            child: Text(
                              'Tgl: ${pa.filterTanggalIso} ✕',
                              style: const TextStyle(
                                color: TemaSaksiWarung.aksenOranye,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Filter bar (Category + Operator)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: widget.modeGelap ? TemaSaksiWarung.panelGelap : Colors.grey.shade200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _chipKategori(pa, KategoriAudit.semua, 'Semua'),
                          _chipKategori(pa, KategoriAudit.anomaliDanOpname, 'Anomali & Opname'),
                          _chipKategori(pa, KategoriAudit.perubahanMaster, 'Edit Harga/Master'),
                          _chipKategori(pa, KategoriAudit.stokDanPenjualan, 'Stok & Laci'),
                          _chipKategori(pa, KategoriAudit.keamananKunci, 'Kunci Shift'),
                        ],
                      ),
                    ),
                    if (widget.daftarOperator.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Semua Penjaga', style: TextStyle(fontSize: 11)),
                              selected: pa.filterIdOperator == null,
                              onSelected: (_) => pa.ubahFilterOperator(null),
                            ),
                            ...widget.daftarOperator.map(
                                  (op) => Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChoiceChip(
                                  label: Text(op.namaPanggilan, style: const TextStyle(fontSize: 11)),
                                  selected: pa.filterIdOperator == op.id,
                                  onSelected: (_) => pa.ubahFilterOperator(
                                    pa.filterIdOperator == op.id ? null : op.id,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Infinite-scroll immutable timeline
              Expanded(
                child: pa.sedangMemuat
                    ? const Center(
                  child: CircularProgressIndicator(color: TemaSaksiWarung.aksenOranye),
                )
                    : pa.timelineAudit.isEmpty
                    ? const Center(
                  child: Text(
                    'Tidak ada catatan audit untuk filter ini.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: pa.timelineAudit.length +
                      (pa.sedangMemuatHalamanBerikut ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    if (idx >= pa.timelineAudit.length) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final item = pa.timelineAudit[idx];
                    final warna = _warnaKategori(item);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.modeGelap
                            ? TemaSaksiWarung.kartuGelap
                            : Colors.white,
                        border: Border(left: BorderSide(color: warna, width: 4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.judul,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                _formatWaktu(item.waktuKejadian),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subjudul,
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (item.detailPerubahan != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.detailPerubahan!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: warna,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            'PENJAGA: ${item.namaOperator}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
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
      ),
    );
  }

  Widget _chipKategori(PengendaliAudit pa, KategoriAudit kat, String label) {
    final terpilih = pa.kategoriDipilih == kat;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        selected: terpilih,
        selectedColor: TemaSaksiWarung.aksenOranye,
        labelStyle: TextStyle(color: terpilih ? Colors.white : null),
        onSelected: (_) => pa.ubahKategori(kat),
      ),
    );
  }
}

class _LegendaDot extends StatelessWidget {
  final Color warna;
  final String label;

  const _LegendaDot({required this.warna, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, color: warna),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}