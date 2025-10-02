import 'dart:convert';

class Profissional {
  final String nome;
  final String telefone;
  final String segmento;
  final String logradouro;
  final String numero;
  final String bairro;
  final String cidade;
  final String uf;
  final String cep;

  Profissional({
    required this.nome,
    required this.telefone,
    required this.segmento,
    this.logradouro = '',
    this.numero = '',
    this.bairro = '',
    this.cidade = '',
    this.uf = '',
    this.cep = '',
  });

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'telefone': telefone,
        'segmento': segmento,
        'logradouro': logradouro,
        'numero': numero,
        'bairro': bairro,
        'cidade': cidade,
        'uf': uf,
        'cep': cep,
      };

  factory Profissional.fromJson(Map<String, dynamic> j) => Profissional(
        nome: j['nome'] ?? '',
        telefone: j['telefone'] ?? '',
        segmento: j['segmento'] ?? '',
        logradouro: j['logradouro'] ?? '',
        numero: j['numero'] ?? '',
        bairro: j['bairro'] ?? '',
        cidade: j['cidade'] ?? '',
        uf: j['uf'] ?? '',
        cep: j['cep'] ?? '',
      );
}

class Cliente {
  final String nome;
  final String telefone;
  final String? placa;

  // NOVOS (opcionais)
  final String? cpfCnpj;
  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? bairro;
  final String? cidade;
  final String? uf;

  Cliente({
    required this.nome,
    required this.telefone,
    this.placa,
    this.cpfCnpj,
    this.cep,
    this.logradouro,
    this.numero,
    this.bairro,
    this.cidade,
    this.uf,
  });

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'telefone': telefone,
        'placa': placa,
        'cpfCnpj': cpfCnpj,
        'cep': cep,
        'logradouro': logradouro,
        'numero': numero,
        'bairro': bairro,
        'cidade': cidade,
        'uf': uf,
      };

  factory Cliente.fromJson(Map<String, dynamic> j) => Cliente(
        nome: j['nome'] ?? '',
        telefone: j['telefone'] ?? '',
        placa: j['placa'],
        cpfCnpj: j['cpfCnpj'],
        cep: j['cep'],
        logradouro: j['logradouro'],
        numero: j['numero'],
        bairro: j['bairro'],
        cidade: j['cidade'],
        uf: j['uf'],
      );
}

class ItemOrcamento {
  final String descricao;
  final double quantidade;
  final String? unidade;
  final double valorUnit;

  ItemOrcamento({
    required this.descricao,
    required this.quantidade,
    this.unidade,
    required this.valorUnit,
  });

  double get subtotal => quantidade * valorUnit;

  Map<String, dynamic> toJson() => {
        'descricao': descricao,
        'quantidade': quantidade,
        'unidade': unidade,
        'valorUnit': valorUnit,
      };

  factory ItemOrcamento.fromJson(Map<String, dynamic> j) => ItemOrcamento(
        descricao: j['descricao'] ?? '',
        quantidade: (j['quantidade'] ?? 0).toDouble(),
        unidade: j['unidade'],
        valorUnit: (j['valorUnit'] ?? 0).toDouble(),
      );
}

class Orcamento {
  final String id; // e.g., "2025-0001"
  final Profissional profissional;
  final Cliente cliente;
  final DateTime data;
  final List<ItemOrcamento> itens;
  final double desconto;
  final double acrescimos;
  final String? observacoes;

  Orcamento({
    required this.id,
    required this.profissional,
    required this.cliente,
    required this.data,
    required this.itens,
    this.desconto = 0,
    this.acrescimos = 0,
    this.observacoes,
  });

  double get subtotal => itens.fold(0.0, (p, e) => p + e.subtotal);
  double get total => subtotal - desconto + acrescimos;

  Map<String, dynamic> toJson() => {
        'id': id,
        'profissional': profissional.toJson(),
        'cliente': cliente.toJson(),
        'data': data.toIso8601String(),
        'itens': itens.map((e) => e.toJson()).toList(),
        'desconto': desconto,
        'acrescimos': acrescimos,
        'observacoes': observacoes,
      };

  factory Orcamento.fromJson(Map<String, dynamic> j) => Orcamento(
        id: j['id'] ?? '',
        profissional: Profissional.fromJson(j['profissional']),
        cliente: Cliente.fromJson(j['cliente']),
        data: DateTime.tryParse(j['data'] ?? '') ?? DateTime.now(),
        itens: ((j['itens'] ?? []) as List)
            .map((e) => ItemOrcamento.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        desconto: (j['desconto'] ?? 0).toDouble(),
        acrescimos: (j['acrescimos'] ?? 0).toDouble(),
        observacoes: j['observacoes'],
      );
}

// helpers
String encodeList(List<Map<String, dynamic>> list) => jsonEncode(list);
List<Map<String, dynamic>> decodeList(String raw) =>
    (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
