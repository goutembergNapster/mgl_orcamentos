import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../widgets/theme.dart';
import '../services/storage_service.dart';
import 'home_page.dart';

enum _AuthMode { signIn, signUp, reset }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _novaSenha = TextEditingController();
  final _confirmaSenha = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  _AuthMode _mode = _AuthMode.signIn;

  final store = StorageService();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Pré-preenche e-mail salvo
    try {
      final savedEmail = await store.getEmail();
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _email.text = savedEmail;
      }
    } catch (_) {}

    // Se já houver token salvo, pula direto para a Home
    try {
      final token = await store.getAuthToken();
      if (token != null && token.isNotEmpty) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    _novaSenha.dispose();
    _confirmaSenha.dispose();
    super.dispose();
  }

  bool _isValidEmail(String v) {
    final s = v.trim();
    if (s.isEmpty) return false;
    final re = RegExp(r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$");
    return re.hasMatch(s);
  }

  Future<void> _entrar() async {
    if (!_isValidEmail(_email.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um e-mail válido.')),
      );
      return;
    }
    if (_senha.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe sua senha.')),
      );
      return;
    }

    setState(() => _loading = true);
    final ok = await store.loginUser(_email.text, _senha.text);
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      // Salva sessão + e-mail (para auto-login e pré-preenchimento)
      await store.saveAuthToken('sess_${DateTime.now().millisecondsSinceEpoch}');
      await store.saveEmail(_email.text.trim());

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail ou senha inválidos.')),
      );
    }
  }

  Future<void> _criarConta() async {
    if (!_isValidEmail(_email.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um e-mail válido para criar conta.')),
      );
      return;
    }
    if (_senha.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Defina uma senha com pelo menos 6 caracteres.')),
      );
      return;
    }

    setState(() => _loading = true);
    final ok = await store.registerUser(_email.text, _senha.text);
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta criada! Faça login.')),
      );
      setState(() => _mode = _AuthMode.signIn);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail já cadastrado.')),
      );
    }
  }

  Future<void> _redefinirSenha() async {
    if (!_isValidEmail(_email.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um e-mail válido para redefinir.')),
      );
      return;
    }
    if (_novaSenha.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nova senha precisa de pelo menos 6 caracteres.')),
      );
      return;
    }
    if (_novaSenha.text.trim() != _confirmaSenha.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senhas não conferem.')),
      );
      return;
    }

    setState(() => _loading = true);
    final ok = await store.changePassword(_email.text, _novaSenha.text);
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha redefinida. Faça login.')),
      );
      setState(() => _mode = _AuthMode.signIn);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail não encontrado.')),
      );
    }
  }

  void _toSignUp() => setState(() => _mode = _AuthMode.signUp);
  void _toReset() => setState(() => _mode = _AuthMode.reset);
  void _toSignIn() => setState(() => _mode = _AuthMode.signIn);

  // DECORAÇÃO: textos/ícones claros (compatível com SDKs sem prefixIconColor/suffixIconColor)
  InputDecoration _dec({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white),
      hintStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignIn = _mode == _AuthMode.signIn;
    final isSignUp = _mode == _AuthMode.signUp;
    final isReset = _mode == _AuthMode.reset;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            // Cabeçalho (cartão azul escuro)
            Card(
              color: AppColors.navy900,
              surfaceTintColor: AppColors.navy900,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Icon(Icons.headset_mic_outlined, size: 96, color: Colors.white),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: Colors.green),
                        SizedBox(width: 8),
                        Text('(31) 98508-2425', style: TextStyle(color: Colors.white)),
                        SizedBox(width: 20),
                        FaIcon(FontAwesomeIcons.instagram, size: 18, color: Colors.pink),
                        SizedBox(width: 8),
                        Text('@mglautomacao', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Bem-vindo a MGL',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Orçamentos personalizados',
                      style: TextStyle(color: Color(0xFFBFC9DA)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Cartão de login/cadastro/reset
            Card(
              color: AppColors.navy900,
              surfaceTintColor: AppColors.navy900,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        isSignIn
                            ? 'Entrar'
                            : isSignUp
                                ? 'Criar conta'
                                : 'Redefinir senha',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec(label: 'E-mail', icon: Icons.alternate_email),
                    ),
                    const SizedBox(height: 12),

                    if (!isReset) ...[
                      TextField(
                        controller: _senha,
                        obscureText: _obscure,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec(
                          label: 'Senha',
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.white70,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    if (isReset) ...[
                      TextField(
                        controller: _novaSenha,
                        obscureText: _obscureNew,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec(
                          label: 'Nova senha',
                          icon: Icons.lock_reset_outlined,
                          suffix: IconButton(
                            tooltip: _obscureNew ? 'Mostrar' : 'Ocultar',
                            icon: Icon(
                              _obscureNew
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.white70,
                            ),
                            onPressed: () =>
                                setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmaSenha,
                        obscureText: _obscureConfirm,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec(
                          label: 'Confirmar senha',
                          icon: Icons.verified_outlined,
                          suffix: IconButton(
                            tooltip: _obscureConfirm ? 'Mostrar' : 'Ocultar',
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.white70,
                            ),
                            onPressed: () =>
                                setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    SizedBox(
                      height: 54,
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _GradientButton(
                              onPressed: isSignIn
                                  ? _entrar
                                  : isSignUp
                                      ? _criarConta
                                      : _redefinirSenha,
                              icon: isSignIn
                                  ? Icons.login_rounded
                                  : isSignUp
                                      ? Icons.person_add_alt_1_rounded
                                      : Icons.lock_reset_rounded,
                              label: isSignIn
                                  ? 'Entrar'
                                  : isSignUp
                                      ? 'Criar conta'
                                      : 'Redefinir senha',
                            ),
                    ),

                    const SizedBox(height: 16),

                    if (isSignIn) ...[
                      Center(
                        child: TextButton(
                          onPressed: _toSignUp,
                          child: const Text('Criar uma conta'),
                        ),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: _toReset,
                          child: const Text('Esqueci minha senha'),
                        ),
                      ),
                    ] else if (isSignUp) ...[
                      Center(
                        child: TextButton(
                          onPressed: _toSignIn,
                          child: const Text('Já tenho conta • Entrar'),
                        ),
                      ),
                    ] else if (isReset) ...[
                      Center(
                        child: TextButton(
                          onPressed: _toSignIn,
                          child: const Text('Voltar ao login'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const _VersionBadge(),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.blueA, AppColors.blueB],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge();

  Future<String> _label() async {
    final info = await PackageInfo.fromPlatform();
    return 'v${info.version}+${info.buildNumber}';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, right: 4),
        child: Opacity(
          opacity: 0.7,
          child: FutureBuilder<String>(
            future: _label(),
            builder: (_, snap) {
              final text = snap.data ?? '...';
              return Text(text, style: Theme.of(context).textTheme.labelSmall);
            },
          ),
        ),
      ),
    );
  }
}
