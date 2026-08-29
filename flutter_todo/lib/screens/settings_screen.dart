import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../repositories/todo_repository.dart';
import '../services/github_api_client.dart';
import '../state/settings_model.dart';
import '../state/todo_list_model.dart';

/// Screen for configuring GitHub repository coordinates (multi-repo support) and Personal Access Token.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _newRepoController;
  late final TextEditingController _tokenController;

  bool _obscureToken = true;
  bool _isTestingConnection = false;
  String? _testSuccessMessage;
  String? _testErrorMessage;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsModel>();
    _newRepoController = TextEditingController();
    _tokenController = TextEditingController(text: settings.token);
  }

  @override
  void dispose() {
    _newRepoController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  String? _validateRepo(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      if (required) return 'Please enter repository (e.g. owner/repo)';
      return null;
    }
    final trimmed = value.trim();
    if (!RegExp(r'^[^/\s]+/[^/\s]+$').hasMatch(trimmed)) {
      return 'Format must be "owner/repo"';
    }
    return null;
  }

  String? _validateToken(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your GitHub Personal Access Token';
    }
    return null;
  }

  Future<void> _testConnection(String repo) async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _testErrorMessage = 'Please enter a GitHub token first.';
        _testSuccessMessage = null;
      });
      return;
    }

    final repoValidationError = _validateRepo(repo, required: true);
    if (repoValidationError != null) {
      setState(() {
        _testErrorMessage = repoValidationError;
        _testSuccessMessage = null;
      });
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _testSuccessMessage = null;
      _testErrorMessage = null;
    });

    final settings = context.read<SettingsModel>();
    try {
      final msg = await settings.testConnection(repo, token);
      if (mounted) {
        setState(() {
          _testSuccessMessage = msg;
          _testErrorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testSuccessMessage = null;
          _testErrorMessage = e is GitHubApiException
              ? e.message
              : e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Future<void> _addNewRepo() async {
    final newRepo = _newRepoController.text.trim();
    final token = _tokenController.text.trim();

    if (token.isEmpty) {
      _formKey.currentState!.validate();
      return;
    }

    final repoError = _validateRepo(newRepo, required: true);
    if (repoError != null) {
      _formKey.currentState!.validate();
      return;
    }

    final settings = context.read<SettingsModel>();
    final todoList = context.read<TodoListModel>();

    try {
      await settings.saveSettings(newRepo, token);

      final apiClient = settings.createApiClient(token);
      final repository = TodoRepository(apiClient: apiClient, repo: newRepo);
      todoList.setRepository(repository);
      todoList.loadTodos();

      _newRepoController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Repository "$newRepo" added and selected!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add repository: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _selectRepo(String repo) async {
    final settings = context.read<SettingsModel>();
    final todoList = context.read<TodoListModel>();

    try {
      await settings.selectActiveRepo(repo);

      final token = settings.token;
      final apiClient = settings.createApiClient(token);
      final repository = TodoRepository(apiClient: apiClient, repo: repo);
      todoList.setRepository(repository);
      todoList.loadTodos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched active repository to "$repo"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch repository: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removeRepo(String repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Repository?'),
        content: Text(
          'Are you sure you want to remove "$repo" from your list? Issues in GitHub will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final settings = context.read<SettingsModel>();
      final todoList = context.read<TodoListModel>();

      await settings.removeRepo(repo);

      if (settings.activeRepo.isNotEmpty) {
        final apiClient = settings.createApiClient();
        final repository = TodoRepository(
          apiClient: apiClient,
          repo: settings.activeRepo,
        );
        todoList.setRepository(repository);
        todoList.loadTodos();
      }
    }
  }

  Future<void> _saveAndOpenTodos() async {
    final settings = context.read<SettingsModel>();
    final token = _tokenController.text.trim();
    final newRepo = _newRepoController.text.trim();

    if (token.isEmpty) {
      _formKey.currentState!.validate();
      return;
    }

    if (settings.repos.isEmpty && newRepo.isEmpty) {
      _formKey.currentState!.validate();
      return;
    }

    final todoList = context.read<TodoListModel>();

    try {
      if (newRepo.isNotEmpty) {
        await settings.saveSettings(newRepo, token);
      } else {
        await settings.settingsStore.saveToken(token);
        await settings.loadSettings();
      }

      if (settings.activeRepo.isNotEmpty) {
        final apiClient = settings.createApiClient(token);
        final repository = TodoRepository(
          apiClient: apiClient,
          repo: settings.activeRepo,
        );
        todoList.setRepository(repository);
        todoList.loadTodos();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.list,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsModel>();
    final repos = settings.repos;
    final activeRepo = settings.activeRepo;

    return Scaffold(
      appBar: AppBar(title: const Text('GitHub Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.settings_outlined,
                  size: 56,
                  color: Colors.indigo,
                ),
                const SizedBox(height: 12),
                Text(
                  'GitHub Configuration',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure your GitHub token and manage multiple repositories.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Personal Access Token Input
                TextFormField(
                  controller: _tokenController,
                  obscureText: _obscureToken,
                  decoration: InputDecoration(
                    labelText: 'Personal Access Token',
                    hintText: 'ghp_...',
                    prefixIcon: const Icon(Icons.key_outlined),
                    border: const OutlineInputBorder(),
                    helperText: 'Requires "Issues: read & write" permission',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureToken ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscureToken = !_obscureToken),
                    ),
                  ),
                  autocorrect: false,
                  validator: _validateToken,
                ),
                const SizedBox(height: 24),

                // Configured Repositories Card
                if (repos.isNotEmpty) ...[
                  Text(
                    'Configured Repositories',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerLow,
                    child: Column(
                      children: repos.map((r) {
                        final isSelected = r == activeRepo;
                        return ListTile(
                          leading: Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                          title: Text(
                            r,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          subtitle: isSelected
                              ? const Text('Active Repository')
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.wifi_tethering,
                                  size: 20,
                                ),
                                tooltip: 'Test Connection to $r',
                                onPressed: _isTestingConnection
                                    ? null
                                    : () => _testConnection(r),
                              ),
                              if (repos.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  tooltip: 'Remove $r',
                                  onPressed: () => _removeRepo(r),
                                ),
                            ],
                          ),
                          onTap: () => _selectRepo(r),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Add New Repository Section
                Text(
                  repos.isEmpty
                      ? 'Target Repository'
                      : 'Add Another Repository',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _newRepoController,
                        decoration: InputDecoration(
                          labelText: 'Repository',
                          hintText: 'owner/repository',
                          prefixIcon: const Icon(Icons.folder_outlined),
                          border: const OutlineInputBorder(),
                          helperText: 'e.g. etnt/mytodos',
                        ),
                        autocorrect: false,
                        validator: (val) =>
                            _validateRepo(val, required: repos.isEmpty),
                      ),
                    ),
                    if (repos.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: FilledButton.tonalIcon(
                          onPressed: _addNewRepo,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Test Connection Banner / Feedback
                if (_testSuccessMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testSuccessMessage!,
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_testErrorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testErrorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Action Buttons
                OutlinedButton.icon(
                  onPressed: _isTestingConnection
                      ? null
                      : () {
                          final repoToTest =
                              _newRepoController.text.trim().isNotEmpty
                              ? _newRepoController.text.trim()
                              : activeRepo;
                          _testConnection(repoToTest);
                        },
                  icon: _isTestingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: const Text('Test Connection'),
                ),
                const SizedBox(height: 12),

                FilledButton.icon(
                  onPressed: settings.isLoading ? null : _saveAndOpenTodos,
                  icon: const Icon(Icons.save),
                  label: settings.isLoading
                      ? const Text('Saving...')
                      : const Text('Save & Open TODOs'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
