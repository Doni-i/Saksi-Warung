import 'package:flutter/material.dart';
import '../../domain/entitas/akun_kasbon.dart';
import '../../inti/keamanan/pengelola_kunci_audit.dart';
import '../../inti/tema/tema_saksi_warung.dart';
import '../widget/logo_saksi_warung.dart';

class LayarKunciAudit extends StatefulWidget {
  final PengelolaKunciAudit pengelolaKunci;
  final List<OperatorWarung> daftarOperator;
  final OperatorWarung? operatorAktif;
  final Future<void> Function(String idOperator) onGantiOperator;

  const LayarKunciAudit({
    super.key,
    required this.pengelolaKunci,
    required this.daftarOperator,
    required this.operatorAktif,
    required this.onGantiOperator,
  });

  @override
  State<LayarKunciAudit> createState() => _LayarKunciAuditState();
}

class _LayarKunciAuditState extends State<LayarKunciAudit> {
  String _pinTerinput = '';
  String? _idOperatorDipilih;
  String? _pesanGalat;
  bool _sedangMemverifikasi = false;

  @override
  void initState() {
    super.initState();
    _idOperatorDipilih = widget.operatorAktif?.id ??
        (widget.daftarOperator.isNotEmpty ? widget.daftarOperator.first.id : 'op_pemilik');
  }

  void _tekanDigit(String digit) {
    if (_sedangMemverifikasi || _pinTerinput.length >= 6) return;
    setState(() {
      _pinTerinput += digit;
      _pesanGalat = null;
    });
  }

  void _hapusDigit() {
    if (_sedangMemverifikasi || _pinTerinput.isEmpty) return;
    setState(() {
      _pinTerinput = _pinTerinput.substring(0, _pinTerinput.length - 1);
      _pesanGalat = null;
    });
  }

  Future<void> _submitPin() async {
    if (_pinTerinput.length < 4) {
      setState(() => _pesanGalat = 'Masukkan minimal 4 digit PIN Audit.');
      return;
    }

    setState(() => _sedangMemverifikasi = true);
    final idOp = _idOperatorDipilih ?? widget.operatorAktif?.id ?? 'op_pemilik';
    final lolos = await widget.pengelolaKunci.verifikasiDanBuka(
      pinInput: _pinTerinput,
      idOperatorPembuka: idOp,
    );

    if (!mounted) return;
    if (lolos) {
      await widget.onGantiOperator(idOp);
      if (!mounted) return;
      setState(() {
        _pinTerinput = '';
        _pesanGalat = null;
        _sedangMemverifikasi = false;
      });
    } else {
      setState(() {
        _pinTerinput = '';
        _pesanGalat = 'PIN Audit salah — percobaan dicatat ke log audit.';
        _sedangMemverifikasi = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pk = widget.pengelolaKunci;
    final pilihanOperator = widget.daftarOperator.isNotEmpty
        ? widget.daftarOperator
        : const [
      OperatorWarung(
        id: 'op_pemilik',
        namaPanggilan: 'PEMILIK',
        aktifSekarang: true,
      ),
    ];

    final nilaiDropdown = pilihanOperator.any((o) => o.id == _idOperatorDipilih)
        ? _idOperatorDipilih
        : pilihanOperator.first.id;

    return Material(
      color: TemaSaksiWarung.latarObsidian,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const SizedBox(height: 8),
                  const LogoSaksiWarung(ukuran: 56),
                  const SizedBox(height: 12),
                  const Text(
                    'SAKSI WARUNG — TERKUNCI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pk.alasanTerkunciTerakhir ?? 'Kunci layar aktif demi integritas buku besar',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  if (pk.percobaanGagalBeruntun > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: TemaSaksiWarung.merahPeringatan.withValues(alpha: 0.2),
                      child: Text(
                        'PERINGATAN AUDIT: ${pk.percobaanGagalBeruntun}x gagal buka PIN tercatat',
                        style: const TextStyle(
                          color: TemaSaksiWarung.merahPeringatan,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: TemaSaksiWarung.kartuGelap,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: nilaiDropdown,
                        isExpanded: true,
                        dropdownColor: TemaSaksiWarung.kartuGelap,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        items: pilihanOperator
                            .map(
                              (op) => DropdownMenuItem(
                            value: op.id,
                            child: Text('BUKA SHIFT SEBAGAI: ${op.namaPanggilan}'),
                          ),
                        )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _idOperatorDipilih = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (idx) {
                      final terisi = idx < _pinTerinput.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: terisi ? TemaSaksiWarung.aksenOranye : Colors.transparent,
                          border: Border.all(
                            color: terisi ? TemaSaksiWarung.aksenOranye : Colors.white38,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 18,
                    child: _pesanGalat != null
                        ? Text(
                      _pesanGalat!,
                      style: const TextStyle(
                        color: TemaSaksiWarung.merahPeringatan,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                        : const Text(
                      'Masukkan PIN Audit (4–6 digit)',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  children: [
                    for (final baris in const [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: baris
                              .map(
                                (angka) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: _tombolKeypad(
                                  label: angka,
                                  onTap: () => _tekanDigit(angka),
                                ),
                              ),
                            ),
                          )
                              .toList(),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: _tombolKeypad(
                              label: 'HAPUS',
                              warnaLatar: TemaSaksiWarung.kartuGelap,
                              ukuranFont: 12,
                              onTap: _hapusDigit,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: _tombolKeypad(
                              label: '0',
                              onTap: () => _tekanDigit('0'),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: _tombolKeypad(
                              label: 'BUKA',
                              warnaLatar: TemaSaksiWarung.aksenOranye,
                              ukuranFont: 13,
                              onTap: _submitPin,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tombolKeypad({
    required String label,
    required VoidCallback onTap,
    Color warnaLatar = TemaSaksiWarung.kartuGelap,
    double ukuranFont = 20,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: warnaLatar,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: const BorderSide(color: Colors.white12),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: ukuranFont),
        ),
      ),
    );
  }
}