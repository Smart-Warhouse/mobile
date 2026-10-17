/// Normalises what a person types in the "Server address" field.
///
/// `192.168.50.2:8000` → `http://192.168.50.2:8000`; trailing slashes and a
/// trailing `/api` are dropped (all REST paths already start with `/api`).
/// Returns null when the input cannot be a server origin.
String? normalizeServerUrl(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  if (!s.contains('://')) s = 'http://$s';
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('/api')) s = s.substring(0, s.length - 4);
  final uri = Uri.tryParse(s);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return s;
}

/// `http://host:8000` + token → `ws://host:8000/ws/live?token=…`
/// (docs/02-api-contract.md §4).
Uri liveSocketUri(String baseUrl, String token) {
  final base = Uri.parse(baseUrl);
  return base.replace(
    scheme: base.scheme == 'https' ? 'wss' : 'ws',
    path: '${base.path}/ws/live',
    queryParameters: {'token': token},
  );
}
