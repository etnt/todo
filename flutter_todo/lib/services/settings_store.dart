import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists application configuration.
///
/// Supports multiple repositories with a selected active repository.
/// Repository coordinates are stored in [SharedPreferences] and
/// the GitHub Personal Access Token is stored securely in Android Keystore via [FlutterSecureStorage].
class SettingsStore {
  SettingsStore({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? sharedPreferences,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _prefs = sharedPreferences;

  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;

  static const legacyRepoKey = 'todo_repo';
  static const reposListKey = 'todo_repos_list';
  static const activeRepoKey = 'todo_active_repo';
  static const tokenKey = 'github_token';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Returns the list of all configured repositories (e.g. `['etnt/mytodos', 'org/project']`).
  Future<List<String>> getRepos() async {
    final prefs = await _getPrefs();
    final list = prefs.getStringList(reposListKey);
    if (list != null && list.isNotEmpty) {
      return List.unmodifiable(list);
    }

    // Migrate from legacy single-repo key if present
    final legacy = prefs.getString(legacyRepoKey);
    if (legacy != null && legacy.trim().isNotEmpty) {
      final migrated = [legacy.trim()];
      await prefs.setStringList(reposListKey, migrated);
      await prefs.setString(activeRepoKey, legacy.trim());
      return List.unmodifiable(migrated);
    }

    return const [];
  }

  /// Returns the currently active repository, or null if none is selected.
  Future<String?> getActiveRepo() async {
    final prefs = await _getPrefs();
    final active = prefs.getString(activeRepoKey);
    if (active != null && active.trim().isNotEmpty) {
      return active.trim();
    }

    // Fallback to first repository in list or legacy single repo
    final repos = await getRepos();
    if (repos.isNotEmpty) {
      await prefs.setString(activeRepoKey, repos.first);
      return repos.first;
    }

    return null;
  }

  /// Backward-compatible alias for [getActiveRepo].
  Future<String?> getRepo() => getActiveRepo();

  /// Sets the currently active repository (must be in the configured repositories list).
  Future<void> setActiveRepo(String repo) async {
    final cleanRepo = repo.trim();
    final prefs = await _getPrefs();
    final repos = (await getRepos()).toSet();
    repos.add(cleanRepo);
    await prefs.setStringList(reposListKey, repos.toList());
    await prefs.setString(activeRepoKey, cleanRepo);
    await prefs.setString(legacyRepoKey, cleanRepo);
  }

  /// Adds a new repository to the list and sets it as active if requested or if it's the first repo.
  Future<void> addRepo(String repo, {bool makeActive = true}) async {
    final cleanRepo = repo.trim();
    if (cleanRepo.isEmpty) return;

    final prefs = await _getPrefs();
    final repos = (await getRepos()).toList();
    if (!repos.contains(cleanRepo)) {
      repos.add(cleanRepo);
      await prefs.setStringList(reposListKey, repos);
    }

    if (makeActive || prefs.getString(activeRepoKey) == null) {
      await prefs.setString(activeRepoKey, cleanRepo);
      await prefs.setString(legacyRepoKey, cleanRepo);
    }
  }

  /// Removes a repository from the list.
  ///
  /// If the removed repository was active, the first remaining repository is activated.
  Future<void> removeRepo(String repo) async {
    final cleanRepo = repo.trim();
    final prefs = await _getPrefs();
    final repos = (await getRepos()).toList()..remove(cleanRepo);
    await prefs.setStringList(reposListKey, repos);

    final currentActive = prefs.getString(activeRepoKey);
    if (currentActive == cleanRepo) {
      if (repos.isNotEmpty) {
        await prefs.setString(activeRepoKey, repos.first);
        await prefs.setString(legacyRepoKey, repos.first);
      } else {
        await prefs.remove(activeRepoKey);
        await prefs.remove(legacyRepoKey);
      }
    }
  }

  /// Backward-compatible alias for saving/activating a repository.
  Future<void> saveRepo(String repo) => addRepo(repo, makeActive: true);

  /// Returns the securely stored GitHub token, or null if not set.
  Future<String?> getToken() async {
    return _secureStorage.read(key: tokenKey);
  }

  /// Persists the GitHub token securely in Android Keystore.
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: tokenKey, value: token.trim());
  }

  /// Returns `true` if at least one repository and a token are configured.
  Future<bool> isConfigured() async {
    final repo = await getActiveRepo();
    final token = await getToken();
    return repo != null && repo.isNotEmpty && token != null && token.isNotEmpty;
  }

  /// Clears all stored repositories and token.
  Future<void> clear() async {
    final prefs = await _getPrefs();
    await prefs.remove(legacyRepoKey);
    await prefs.remove(reposListKey);
    await prefs.remove(activeRepoKey);
    await _secureStorage.delete(key: tokenKey);
  }
}
