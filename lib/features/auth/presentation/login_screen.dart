import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/l10n/labels.dart';
import '../../../core/network/server_url.dart';
import '../../../core/providers.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/theme/sw_tokens.dart';
import 'providers/session_controller.dart';

/// Use case 1: server address + username/password. The address and the
/// username are remembered (shared_preferences); the JWT goes to secure
/// storage; the password is never stored.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _server;
  late final TextEditingController _user;
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(appPrefsProvider);
    _server = TextEditingController(
      text: prefs.serverUrl ?? AppPrefs.defaultServerUrl,
    );
    _user = TextEditingController(text: prefs.lastUsername ?? '');
  }

  @override
  void dispose() {
    _server.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final url = normalizeServerUrl(_server.text);
    final l10n = context.l10n;
    if (url == null) {
      setState(() => _error = l10n.serverUrlInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final res = await ref
        .read(sessionControllerProvider.notifier)
        .testServer(url);
    if (!mounted) return;
    setState(() {
      _busy = false;
      res.when(
        ok: (h) => _info = l10n.serverReachable(h.version ?? '?'),
        err: (f) => _error = l10n.failure(f),
      );
    });
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final url = normalizeServerUrl(_server.text)!;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final res = await ref
        .read(sessionControllerProvider.notifier)
        .login(
          baseUrl: url,
          username: _user.text.trim(),
          password: _password.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res.failureOrNull case final f?) _error = l10n.failure(f);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.sw;
    final text = Theme.of(context).textTheme;
    final expired = switch (ref.watch(sessionControllerProvider)) {
      SignedOut(:final expired) => expired,
      _ => false,
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Sp.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: t.lift,
                            borderRadius: BorderRadius.circular(Sp.radius),
                          ),
                          child: Icon(PhosphorIconsFill.truck, color: t.liftOn),
                        ),
                        const SizedBox(width: Sp.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.appTitle, style: text.headlineSmall),
                            Text(
                              l10n.appShort,
                              style: text.bodySmall?.copyWith(color: t.text3),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: Sp.xl),
                    Text(l10n.loginTitle, style: text.titleLarge),
                    Text(
                      l10n.loginSubtitle,
                      style: text.bodyMedium?.copyWith(color: t.text2),
                    ),
                    if (expired) ...[
                      const SizedBox(height: Sp.md),
                      _Notice(text: l10n.sessionExpired, color: t.warning),
                    ],
                    const SizedBox(height: Sp.xl),
                    TextFormField(
                      controller: _server,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: l10n.serverUrlLabel,
                        helperText: l10n.serverUrlHelper,
                        helperMaxLines: 3,
                        prefixIcon: const Icon(PhosphorIconsRegular.hardDrives),
                        suffixIcon: IconButton(
                          tooltip: l10n.testConnection,
                          icon: const Icon(PhosphorIconsRegular.plugsConnected),
                          onPressed: _busy ? null : _test,
                        ),
                      ),
                      validator: (v) => normalizeServerUrl(v ?? '') == null
                          ? l10n.serverUrlInvalid
                          : null,
                    ),
                    const SizedBox(height: Sp.lg),
                    TextFormField(
                      controller: _user,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: InputDecoration(
                        labelText: l10n.usernameLabel,
                        prefixIcon: const Icon(PhosphorIconsRegular.user),
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? l10n.requiredField : null,
                    ),
                    const SizedBox(height: Sp.lg),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textDirection: TextDirection.ltr,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        prefixIcon: const Icon(PhosphorIconsRegular.lockSimple),
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? l10n.showPassword
                              : l10n.hidePassword,
                          icon: Icon(
                            _obscure
                                ? PhosphorIconsRegular.eye
                                : PhosphorIconsRegular.eyeSlash,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v ?? '').isEmpty ? l10n.requiredField : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: Sp.md),
                      _Notice(text: _error!, color: t.danger),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: Sp.md),
                      _Notice(text: _info!, color: t.success),
                    ],
                    const SizedBox(height: Sp.xl),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.signIn),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Sp.radiusSm),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color)),
    ),
  );
}
