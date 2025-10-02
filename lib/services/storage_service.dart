import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

import 'package:orcamento_app/models.dart';

class StorageService {
  // ---- NOVOS MÉTODOS p/ orçamentos ----
  Future<void> deleteOrcamentoById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList('orcamentos') ?? <String>[]);
    list.removeWhere((s) {
      try {
        final m = Orcamento.fromJson(jsonDecode(s));
        return m.id == id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList('orcamentos', list);
  }

  Future<void> updateOrcamento(Orcamento updated) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList('orcamentos') ?? <String>[]);
    for (int i = 0; i < list.length; i++) {
      try {
        final m = Orcamento.fromJson(jsonDecode(list[i]));
        if (m.id == updated.id) {
          list[i] = jsonEncode(updated.toJson());
          await prefs.setStringList('orcamentos', list);
          return;
        }
      } catch (_) {}
    }
    // se não achou, adiciona
    list.add(jsonEncode(updated.toJson()));
    await prefs.setStringList('orcamentos', list);
  }

  // --------- CLIENTES ----------
  // Dedupe por telefone OU CPF/CNPJ (normalizados sem formatação)
  Future<void> saveCliente(Cliente c) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList('clientes') ?? <String>[]);

    final tel = (c.telefone).replaceAll(RegExp(r'\D'), '');
    final doc = (c.cpfCnpj ?? '').replaceAll(RegExp(r'\D'), '');

    final exists = list.any((s) {
      final m = Cliente.fromJson(jsonDecode(s));
      final mTel = (m.telefone).replaceAll(RegExp(r'\D'), '');
      final mDoc = (m.cpfCnpj ?? '').replaceAll(RegExp(r'\D'), '');
      final sameTel = tel.isNotEmpty && mTel == tel;
      final sameDoc = doc.isNotEmpty && mDoc == doc;
      return sameTel || sameDoc;
    });

    if (!exists) {
      list.add(jsonEncode(c.toJson()));
      await prefs.setStringList('clientes', list);
    }
  }
  // Lista todos os clientes salvos
  Future<List<Cliente>> getClientes() async {
  final prefs = await SharedPreferences.getInstance();
  final list = (prefs.getStringList('clientes') ?? <String>[]);
  // garante que entradas corrompidas não quebrem a lista
  final out = <Cliente>[];
  for (final s in list) {
    try {
      out.add(Cliente.fromJson(jsonDecode(s)));
    } catch (_) {}
  }
  return out;
}
  Future<void> removeCliente(Cliente c) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList('clientes') ?? <String>[]);
    final tel = (c.telefone).replaceAll(RegExp(r'\D'), '');
    final doc = (c.cpfCnpj ?? '').replaceAll(RegExp(r'\D'), '');

    list.removeWhere((s) {
      final m = Cliente.fromJson(jsonDecode(s));
      final mTel = (m.telefone).replaceAll(RegExp(r'\D'), '');
      final mDoc = (m.cpfCnpj ?? '').replaceAll(RegExp(r'\D'), '');
      final sameTel = tel.isNotEmpty && mTel == tel;
      final sameDoc = doc.isNotEmpty && mDoc == doc;
      return sameTel || sameDoc;
    });

    await prefs.setStringList('clientes', list);
  }

  // --------- LOGO ----------
  Future<void> saveLogoBytes(Uint8List? bytes) async {
    final prefs = await SharedPreferences.getInstance();
    if (bytes == null) {
      await prefs.remove('logo_base64');
    } else {
      await prefs.setString('logo_base64', base64Encode(bytes));
    }
  }

  Future<Uint8List?> getLogoBytes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('logo_base64');
    if (raw == null || raw.isEmpty) return null;
    return Uint8List.fromList(base64Decode(raw));
  }

  // --------- PERFIL PROFISSIONAL ----------
  Future<void> savePerfilProfissional(Profissional p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('perfil_prof', jsonEncode(p.toJson()));
  }

  Future<Profissional?> getPerfilProfissional() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('perfil_prof');
    if (raw == null) return null;
    return Profissional.fromJson(jsonDecode(raw));
  }

  /// Remover perfil profissional de forma persistente
  Future<void> deletePerfilProfissional() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('perfil_prof');
  }

  // Aliases para compatibilidade com possíveis chamadas antigas
  Future<void> clearPerfilProfissional() => deletePerfilProfissional();
  Future<void> removePerfilProfissional() => deletePerfilProfissional();

  // --------- ORÇAMENTOS ----------
  Future<String> nextOrcId() async {
    final prefs = await SharedPreferences.getInstance();
    final y = DateTime.now().year;
    final key = 'orc_seq_$y';
    final n = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, n);
    return '$y-${n.toString().padLeft(4, '0')}';
  }

  Future<void> saveOrcamento(Orcamento o) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList('orcamentos') ?? <String>[]);
    list.add(jsonEncode(o.toJson()));
    await prefs.setStringList('orcamentos', list);
  }

  Future<List<Orcamento>> getOrcamentos() async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList('orcamentos') ?? <String>[]);
    return list.map((s) => Orcamento.fromJson(jsonDecode(s))).toList();
  }

  // --------- n8n: Webhook + Toggle ----------
  Future<void> setWebhookUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webhook_url', url);
  }

  Future<String?> getWebhookUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('webhook_url');
  }

  Future<void> setSendOnGenerate(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('send_on_generate', v);
  }

  Future<bool?> getSendOnGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('send_on_generate');
  }

  // --------- Tema ----------
  Future<void> setDarkMode(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', v);
  }

  Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('dark_mode') ?? false;
  }

  // --------- Campos personalizados do Cliente ----------
  Future<void> setCustomClientFields(List<String> fields) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_client_fields', fields);
  }

  Future<List<String>> getCustomClientFields() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('custom_client_fields') ?? <String>[];
  }

  // =======================================================================
  // ======================  A U T E N T I C A Ç Ã O  ======================
  // =======================================================================

  static const _kUsersLegacy = 'users';
  static const _kUsersSecure = 'auth_users';

  // Sessão & e-mail lembrado
  static const _kAuthToken = 'auth_token';
  static const _kSavedEmail = 'saved_email';

  Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAuthToken, token);
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAuthToken);
  }

  Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAuthToken);
  }

  Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSavedEmail, email);
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSavedEmail);
  }

  Future<void> clearEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSavedEmail);
  }

  // --- Helpers internos (auth) ---
  Future<Map<String, dynamic>> _getSecureUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUsersSecure);
    if (raw == null || raw.isEmpty) return {};
    try {
      final obj = jsonDecode(raw);
      if (obj is Map<String, dynamic>) return obj;
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _setSecureUsers(Map<String, dynamic> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsersSecure, jsonEncode(users));
  }

  Future<List<Map<String, dynamic>>> _getLegacyUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kUsersLegacy) ?? <String>[];
    return list.map((s) {
      try {
        final m = jsonDecode(s);
        return (m is Map<String, dynamic>) ? m : <String, dynamic>{};
      } catch (_) {
        return <String, dynamic>{};
      }
    }).toList();
  }

  Future<void> _setLegacyUsers(List<Map<String, dynamic>> users) async {
    final prefs = await SharedPreferences.getInstance();
    final list = users.map((m) => jsonEncode(m)).toList();
    await prefs.setStringList(_kUsersLegacy, list);
  }

  String _randomSalt([int len = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(len, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt::$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // --- API pública (auth) ---
  Future<bool> userExists(String email) async {
    final key = email.toLowerCase().trim();
    final secure = await _getSecureUsers();
    if (secure.containsKey(key)) return true;

    final legacy = await _getLegacyUsers();
    return legacy.any(
      (m) => (m['email'] ?? '').toString().toLowerCase().trim() == key,
    );
  }

  Future<bool> registerUser(String email, String senha) async {
    final key = email.toLowerCase().trim();

    final users = await _getSecureUsers();
    if (users.containsKey(key)) return false;

    final legacy = await _getLegacyUsers();
    if (legacy.any((m) => (m['email'] ?? '').toString().toLowerCase().trim() == key)) {
      return false;
    }

    final salt = _randomSalt();
    final hash = _hashPassword(senha, salt);
    users[key] = {'hash': hash, 'salt': salt};

    await _setSecureUsers(users);
    return true;
  }

  Future<bool> loginUser(String email, String senha) async {
    final key = email.toLowerCase().trim();

    // 1) Novo formato
    final users = await _getSecureUsers();
    final u = users[key];
    if (u is Map) {
      final salt = (u['salt'] ?? '').toString();
      final hash = _hashPassword(senha, salt);
      return hash == (u['hash'] ?? '').toString();
    }

    // 2) Legado (migra)
    final legacy = await _getLegacyUsers();
    final idx = legacy.indexWhere(
      (m) => (m['email'] ?? '').toString().toLowerCase().trim() == key,
    );
    if (idx >= 0) {
      final ok = (legacy[idx]['pass'] ?? '') == senha;
      if (ok) {
        final salt = _randomSalt();
        final hash = _hashPassword(senha, salt);
        users[key] = {'hash': hash, 'salt': salt};
        await _setSecureUsers(users);

        legacy.removeAt(idx);
        await _setLegacyUsers(legacy);
        return true;
      }
    }

    return false;
  }

  Future<bool> changePassword(String email, String newPassword) async {
    final key = email.toLowerCase().trim();

    final users = await _getSecureUsers();
    final salt = _randomSalt();
    final hash = _hashPassword(newPassword, salt);
    users[key] = {'hash': hash, 'salt': salt};
    await _setSecureUsers(users);

    // remove do legado (se existir)
    final legacy = await _getLegacyUsers();
    final filtered = legacy
        .where((m) => (m['email'] ?? '').toString().toLowerCase().trim() != key)
        .toList();
    await _setLegacyUsers(filtered);

    return true;
  }

  Future<void> logout() async {
    await clearAuthToken();
  }
}
