import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class AuthService {
  static final AuthService _i = AuthService._();
  AuthService._();
  factory AuthService() => _i;

  String? get _api => (dotenv.env['API_URL'] ?? '').trim().isEmpty ? null : dotenv.env['API_URL']!.trim();

  Future<bool> isLoggedIn() async {
    final sp = await SharedPreferences.getInstance();
    // se usa API, verifica se tem token
    if (_api != null) {
      final t = sp.getString('auth_token');
      return t != null && t.isNotEmpty;
    }
    // local
    return sp.getBool('auth_logged') ?? false;
  }

  Future<bool> userExists(String email) async {
    if (_api != null) {
      // checagem via register: API devolve ok:false se já existe
      final r = await http.post(Uri.parse('$_api/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': '__probe__'}));
      try {
        final j = jsonDecode(r.body);
        if (j is Map && j['ok'] == false && (j['msg'] ?? '').toString().contains('Email já cadastrado')) {
          return true;
        }
      } catch (_) {}
      return false;
    } else {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('auth_users') ?? '{}';
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      return map.containsKey(email.toLowerCase());
    }
  }

  Future<bool> register(String email, String password) async {
    if (_api != null) {
      final r = await http.post(Uri.parse('$_api/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}));
      final j = jsonDecode(r.body);
      if (j['ok'] == true) {
        // faz login para obter token
        return await login(email, password);
      }
      return false;
    } else {
      final sp = await SharedPreferences.getInstance();
      final low = email.toLowerCase();
      final raw = sp.getString('auth_users') ?? '{}';
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      if (map.containsKey(low)) return false;
      map[low] = _hash(password);
      await sp.setString('auth_users', jsonEncode(map));
      await sp.setString('auth_email', low);
      await sp.setBool('auth_logged', true);
      return true;
    }
  }

  Future<bool> login(String email, String password) async {
    if (_api != null) {
      final r = await http.post(Uri.parse('$_api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final j = jsonDecode(r.body);
        if (j['ok'] == true && (j['token'] ?? '').toString().isNotEmpty) {
          final sp = await SharedPreferences.getInstance();
          await sp.setString('auth_token', j['token']);
          await sp.setString('auth_email', email.toLowerCase());
          return true;
        }
      }
      return false;
    } else {
      final sp = await SharedPreferences.getInstance();
      final low = email.toLowerCase();
      final raw = sp.getString('auth_users') ?? '{}';
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      if (!map.containsKey(low)) return false;
      final ok = map[low] == _hash(password);
      if (ok) {
        await sp.setString('auth_email', low);
        await sp.setBool('auth_logged', true);
      }
      return ok;
    }
  }

  Future<void> logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('auth_token');
    await sp.setBool('auth_logged', false);
  }

  Future<String?> get token async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('auth_token');
  }

  String _hash(String s) => sha256.convert(utf8.encode(s)).toString();
}
