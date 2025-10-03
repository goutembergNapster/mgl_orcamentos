// lib/services/pdf_service.dart
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:orcamento_app/models.dart';

Future<pw.Font> _safeLoadTtf(String assetPath, {pw.Font? fallback}) async {
  try {
    final data = await rootBundle.load(assetPath);
    if (data.lengthInBytes > 0) {
      return pw.Font.ttf(data);
    }
  } catch (_) {
    // ignora e usa fallback
  }
  return fallback ?? pw.Font.helvetica();
}

pw.Widget _watermark(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) return pw.SizedBox();
  return pw.Opacity(
    opacity: 0.08, // bem discreto
    child: pw.Center(
      child: pw.Image(
        pw.MemoryImage(bytes),
        width: 320, // tamanho seguro para A4
        height: 320,
        fit: pw.BoxFit.contain,
      ),
    ),
  );
}

/// Gera um PDF no layout do mock com fallback de fonte robusto
/// e com marca d'água leve centralizada (logo do cliente).
Future<Uint8List> gerarPdfBytes(
  Orcamento orc, {
  Uint8List? logoBytes,
}) async {
  // ====== FONTES (com fallback) ======
  final roboto = await _safeLoadTtf(
    'assets/fonts/Roboto-Regular.ttf',
    fallback: pw.Font.helvetica(),
  );
  final robotoBold = await _safeLoadTtf(
    'assets/fonts/Roboto-Bold.ttf',
    fallback: pw.Font.helveticaBold(),
  );

  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: roboto, bold: robotoBold),
  );

  final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  String s(String? v) => (v ?? '').trim();
  double n(num? v) => (v == null) ? 0.0 : v.toDouble();
  String fmtDate(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);

  final itens = orc.itens ?? <ItemOrcamento>[];

  // ====== HEADER (sem marca da app; só info do orçamento) ======
  pw.Widget headerLeft() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ORÇAMENTO #${s(orc.id)}',
            style: pw.TextStyle(font: robotoBold, fontSize: 14),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Data: ${fmtDate(orc.data)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: 190,
            height: 3,
            color: PdfColor.fromInt(0xFF2563EB),
          ),
        ],
      );

  pw.Widget logoBox() {
    if (logoBytes != null && logoBytes!.isNotEmpty) {
      return pw.Container(
        width: 110,
        height: 110,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        padding: const pw.EdgeInsets.all(6),
        child: pw.Image(pw.MemoryImage(logoBytes!), fit: pw.BoxFit.contain),
      );
    }
    return pw.Container(
      width: 110,
      height: 110,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text('LOGO', style: pw.TextStyle(fontSize: 12)),
    );
  }

  // ====== BLOCOS DE DADOS ======
  pw.Widget blocoProfissional() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(s(orc.profissional.nome),
              style: pw.TextStyle(font: robotoBold, fontSize: 12)),
          if (s(orc.profissional.segmento).isNotEmpty)
            pw.Text(s(orc.profissional.segmento),
                style: const pw.TextStyle(fontSize: 10)),
          if (s(orc.profissional.telefone).isNotEmpty)
            pw.Text('Tel: ${s(orc.profissional.telefone)}',
                style: const pw.TextStyle(fontSize: 10)),
          if (s(orc.profissional.logradouro).isNotEmpty ||
              s(orc.profissional.numero).isNotEmpty)
            pw.Text(
              '${s(orc.profissional.logradouro)}'
              '${s(orc.profissional.numero).isNotEmpty ? ', ${s(orc.profissional.numero)}' : ''}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          if (s(orc.profissional.bairro).isNotEmpty ||
              s(orc.profissional.cidade).isNotEmpty ||
              s(orc.profissional.uf).isNotEmpty)
            pw.Text(
              '${s(orc.profissional.bairro)}'
              '${s(orc.profissional.bairro).isNotEmpty && (s(orc.profissional.cidade).isNotEmpty || s(orc.profissional.uf).isNotEmpty) ? ' - ' : ''}'
              '${s(orc.profissional.cidade)}'
              '${s(orc.profissional.uf).isNotEmpty ? ' - ${s(orc.profissional.uf)}' : ''}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          if (s(orc.profissional.cep).isNotEmpty)
            pw.Text('CEP: ${s(orc.profissional.cep)}',
                style: const pw.TextStyle(fontSize: 10)),
        ],
      );

  pw.Widget blocoCliente() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Cliente', style: pw.TextStyle(font: robotoBold, fontSize: 12)),
          pw.Text(s(orc.cliente.nome), style: const pw.TextStyle(fontSize: 11)),
          if (s(orc.cliente.telefone).isNotEmpty)
            pw.Text(s(orc.cliente.telefone),
                style: const pw.TextStyle(fontSize: 10)),
          if (s(orc.cliente.placa).isNotEmpty)
            pw.Text('Placa: ${s(orc.cliente.placa)}',
                style: const pw.TextStyle(fontSize: 10)),
          if (s(orc.cliente.cpfCnpj).isNotEmpty)
            pw.Text('CPF/CNPJ: ${s(orc.cliente.cpfCnpj)}',
                style: const pw.TextStyle(fontSize: 10)),

          // Endereço do cliente (opcional)
          if ([
            s(orc.cliente.logradouro),
            s(orc.cliente.numero),
            s(orc.cliente.bairro),
            s(orc.cliente.cidade),
            s(orc.cliente.uf),
            s(orc.cliente.cep),
          ].any((e) => e.isNotEmpty)) ...[
            if (s(orc.cliente.logradouro).isNotEmpty ||
                s(orc.cliente.numero).isNotEmpty)
              pw.Text(
                '${s(orc.cliente.logradouro)}'
                '${s(orc.cliente.numero).isNotEmpty ? ', ${s(orc.cliente.numero)}' : ''}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            if (s(orc.cliente.bairro).isNotEmpty ||
                s(orc.cliente.cidade).isNotEmpty ||
                s(orc.cliente.uf).isNotEmpty)
              pw.Text(
                '${s(orc.cliente.bairro)}'
                '${s(orc.cliente.bairro).isNotEmpty && (s(orc.cliente.cidade).isNotEmpty || s(orc.cliente.uf).isNotEmpty) ? ' - ' : ''}'
                '${s(orc.cliente.cidade)}'
                '${s(orc.cliente.uf).isNotEmpty ? ' - ${s(orc.cliente.uf)}' : ''}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            if (s(orc.cliente.cep).isNotEmpty)
              pw.Text('CEP: ${s(orc.cliente.cep)}',
                  style: const pw.TextStyle(fontSize: 10)),
          ],
        ],
      );

  pw.Widget tabelaItens() {
    final headers = ['Descrição', 'Qtd', 'V. Unit', 'Subtotal'];
    final rows = itens.map((i) {
      final qtd = n(i.quantidade);
      final vu = n(i.valorUnit);
      final sub = qtd * vu;
      return [
        s(i.descricao).isEmpty ? '-' : i.descricao,
        qtd.toStringAsFixed(1) +
            (s(i.unidade).isNotEmpty ? ' ${s(i.unidade)}' : ''),
        currency.format(vu),
        currency.format(sub),
      ];
    }).toList();

    final headerGrad = pw.LinearGradient(
      colors: [
        PdfColor.fromHex('#1E40AF'),
        PdfColor.fromHex('#2563EB'),
      ],
      begin: pw.Alignment.centerLeft,
      end: pw.Alignment.centerRight,
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1.4),
        3: pw.FlexColumnWidth(1.4),
      },
      children: [
        // Cabeçalho
        pw.TableRow(
          decoration: pw.BoxDecoration(gradient: headerGrad),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 8, horizontal: 6),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        font: robotoBold,
                        color: PdfColors.white,
                        fontSize: 10,
                      ),
                    ),
                  ))
              .toList(),
        ),
        // Linhas
        ...rows.map(
          (r) => pw.TableRow(
            children: r
                .map((c) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 6, horizontal: 6),
                      child: pw.Text(
                        c,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  pw.Widget boxTotais() {
    final desconto = n(orc.desconto);
    final acres = n(orc.acrescimos);
    final total = n(orc.total);

    return pw.Container(
      width: 260,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _rowKV('Desconto', currency.format(desconto), roboto),
          _rowKV('Acréscimos', currency.format(acres), roboto),
          pw.Divider(),
          _rowKV('TOTAL', currency.format(total), robotoBold),
        ],
      ),
    );
  }

  // ====== DOCUMENTO (conteúdo) ======
  final content = <pw.Widget>[
    // Topo: sem título da app; só dados do orçamento + logo
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: headerLeft()),
        logoBox(),
      ],
    ),
    pw.SizedBox(height: 16),

    // Profissional x Cliente
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: blocoProfissional()),
        pw.SizedBox(width: 40),
        pw.Expanded(child: blocoCliente()),
      ],
    ),
    pw.SizedBox(height: 14),

    // Tabela
    tabelaItens(),
    pw.SizedBox(height: 10),

    // Totais à direita
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [boxTotais()],
    ),

    // Observações
    if (s(orc.observacoes).isNotEmpty) ...[
      pw.SizedBox(height: 18),
      pw.Text('Observações',
          style: pw.TextStyle(font: robotoBold, fontSize: 12)),
      pw.SizedBox(height: 6),
      // Observações já chegam formatadas (linhas com "- ") pelo Home
      pw.Text(
        s(orc.observacoes),
        style: const pw.TextStyle(fontSize: 11),
      ),
    ],

    pw.SizedBox(height: 14),
    pw.Text(
      'Validade: 7 dias : Preços sujeitos à alteração sem aviso prévio.',
      style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
    ),
  ];

  // ====== PÁGINA COM MARCA D’ÁGUA (logo central) ======
  final pageTheme = pw.PageTheme(
    margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 32),
    buildBackground: (ctx) => _watermark(logoBytes),
  );

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pageTheme,
      build: (_) => content,
    ),
  );

  return pdf.save();
}

pw.Widget _rowKV(String k, String v, pw.Font f) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(k, style: pw.TextStyle(font: f, fontSize: 11)),
        pw.Text(v, style: pw.TextStyle(font: f, fontSize: 11)),
      ],
    );
