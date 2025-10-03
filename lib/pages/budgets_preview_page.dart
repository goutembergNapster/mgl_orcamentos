// lib/pages/budgets_preview_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

import '../models.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../widgets/theme.dart';

class BudgetPreviewPage extends StatefulWidget {
  const BudgetPreviewPage({super.key, required this.orc});
  final Orcamento orc;

  @override
  State<BudgetPreviewPage> createState() => _BudgetPreviewPageState();
}

class _BudgetPreviewPageState extends State<BudgetPreviewPage> {
  final _store = StorageService();
  Uint8List? _logoBytes;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    final bytes = await _store.getLogoBytes();
    if (!mounted) return;
    setState(() => _logoBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Orçamento #${widget.orc.id}'),
        flexibleSpace: AppTheme.appBarGradientBackground(),
        elevation: 0,
      ),
      body: PdfPreview(
        build: (PdfPageFormat format) async {
          return gerarPdfBytes(widget.orc, logoBytes: _logoBytes);
        },
        allowPrinting: true,   // mostra ação de imprimir
        allowSharing: true,    // mostra ação de compartilhar
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: 'orcamento_${widget.orc.id}.pdf',
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }
}
