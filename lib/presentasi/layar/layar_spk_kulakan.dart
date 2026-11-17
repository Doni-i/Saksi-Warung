import 'package:flutter/material.dart';
import '../../inti/tema/tema_saksi_warung.dart';
import '../pengendali/pengendali_spk.dart';

class LayarSpkKulakan extends StatefulWidget {
  final PengendaliSpk pengendaliSpk;
  final bool modeGelap;

  const LayarSpkKulakan({
    super.key,
    required this.pengendaliSpk,
    required this.modeGelap,
  });

  @override
  State<LayarSpkKulakan> createState() => _LayarSpkKulakanState();
}

class _LayarSpkKulakanState extends State<LayarSpkKulakan> {
  @override
  void initState() {
    super.initState();
    widget.pengendaliSpk.muatDanHitung();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.pengendaliSpk,
      builder: (context, _) {
        final ps = widget.pengendaliSpk;
        final laporan = ps.laporanTerbaru;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: widget.modeGelap ? TemaSaksiWarung.kartuGelap : TemaSaksiWarung.latarObsidian,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SPK PRIORITAS KULAKAN (AHP + TOPSIS)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: TemaSaksiWarung.aksenOranye),
                    onPressed: () => ps.muatDanHitung(),
                  ),
                ],
              ),
            ),
            if (laporan != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: laporan.evaluasiAhp.konsisten
                    ? TemaSaksiWarung.hijauAman.withValues(alpha: 0.15)
                    : TemaSaksiWarung.merahPeringatan.withValues(alpha: 0.15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AHP Consistency Ratio (CR): ${laporan.evaluasiAhp.consistencyRatio.toStringAsFixed(3)} '
                          '(${laporan.evaluasiAhp.konsisten ? "KONSISTEN < 0.10" : "TIDAK KONSISTEN >= 0.10"})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: laporan.evaluasiAhp.konsisten
                            ? TemaSaksiWarung.hijauAman
                            : TemaSaksiWarung.merahPeringatan,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bobot: Laku ${(laporan.evaluasiAhp.bobotTernormalisasi[0] * 100).toStringAsFixed(0)}% | '
                          'Stok ${(laporan.evaluasiAhp.bobotTernormalisasi[1] * 100).toStringAsFixed(0)}% | '
                          'Margin ${(laporan.evaluasiAhp.bobotTernormalisasi[2] * 100).toStringAsFixed(0)}% | '
                          'Anomali ${(laporan.evaluasiAhp.bobotTernormalisasi[3] * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Expanded(child: Text('Prioritas Laku vs Margin:', style: TextStyle(fontSize: 12))),
                  DropdownButton<double>(
                    value: ps.matriksAhp[0][2],
                    items: const [
                      DropdownMenuItem(value: 1.0, child: Text('Seimbang (1)')),
                      DropdownMenuItem(value: 3.0, child: Text('Laku Lebih Penting (3)')),
                      DropdownMenuItem(value: 5.0, child: Text('Laku Sangat Penting (5)')),
                      DropdownMenuItem(value: 1 / 3, child: Text('Margin Lebih Penting (1/3)')),
                    ],
                    onChanged: (v) {
                      if (v != null) ps.perbaruiPreferensiPasangan(0, 2, v);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ps.sedangMenghitung || laporan == null
                  ? const Center(child: CircularProgressIndicator(color: TemaSaksiWarung.aksenOranye))
                  : ListView.builder(
                itemCount: laporan.daftarPeringkat.length,
                itemBuilder: (ctx, idx) {
                  final item = laporan.daftarPeringkat[idx];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: idx == 0 ? TemaSaksiWarung.aksenOranye : Colors.grey.shade800,
                      child: Text('#${item.peringkat}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    title: Text(item.namaBarang, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(item.alasanUtama, style: const TextStyle(fontSize: 11)),
                    trailing: Text(
                      'Ci: ${item.skorPreferensiTopsis.toStringAsFixed(3)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: TemaSaksiWarung.aksenOranye),
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