import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists application configuration.
class SettingsStore {
  SettingsStore({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? sharedPreferences,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _prefs = sharedPreferences;

  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;

  static const repoKey = 'todo_repo';
  static const tokenKey = 'github_token';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Returns the configured repository (e.g. `owner/repo`), or null if not set.
  Future<String?> getRepo() async {
    final prefs = await _getPrefs();
    return prefs.getString(repoKey);
  }

  /// Persists the configured repository string.
  Future<void> saveRepo(String repo) async {
    final prefs = await _getPrefs();
    await prefs.setString(repoKey, repo.trim());
  }

  /// Returns the securely stored GitHub token, or null if not set.
  Future<String?> getToken() async {
    return _secureStorage.read(key: tokenKey);
  }

  /// Persists the GitHub token securely in Android Keystore.
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: tokenKey, value: token.trim());
  }

  /// Returns `true` if both repository and token are configured.
  Future<bool> isConfigured() async {
    final repo = await getRepo();
    final token = await getToken();
    return repo != null && repo.isNotEmpty && token != null && token.isNotEmpty;
  }

  /// Clears stored repository and token.
  Future<void> clear() async {
    final prefs = await _getPrefs();
    await prefs.remove(repoKey);
    await _secureStorage.delete(key: tokenKey);
  }
}
