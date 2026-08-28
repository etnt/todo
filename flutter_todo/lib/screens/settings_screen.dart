import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../repositories/todo_repository.dart';
import '../services/github_api_client.dart';
import '../state/settings_model.dart';
import '../state/todo_list_model.dart';

/// Screen for configuring GitHub repository coordinate and personal access token.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _repoController;
  late final TextEditingController _tokenController;

  bool _obscureToken = true;
  bool _isTestingConnection = false;
  String? _testSuccessMessage;
  String? _testErrorMessage;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsModel>();
    _repoController = TextEditingController(text: settings.repo);
    _tokenController = TextEditingController(text: settings.token);
  }

  @override
  void dispose() {
    _repoController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  String? _validateRepo(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter repository (e.g. owner/repo)';
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

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTestingConnection = true;
      _testSuccessMessage = null;
      _testErrorMessage = null;
    });

    final settings = context.read<SettingsModel>();
    try {
      final msg = await settings.testConnection(
        _repoController.text,
        _tokenController.text,
      );
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
          _testErrorMessage = e is GitHubApiException ? e.message : e.toString();
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

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final settings = context.read<SettingsModel>();
    final todoList = context.read<TodoListModel>();

    try {
      final repo = _repoController.text.trim();
      final token = _tokenController.text.trim();

      await settings.saveSettings(repo, token);

      final apiClient = GitHubApiClient(token: token);
      final repository = TodoRepository(apiClient: apiClient, repo: repo);
      todoList.setRepository(repository);
      todoList.loadTodos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!')),
        );
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.list, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub Settings'),
      ),
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
                  'Connect to GitHub',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'TODOs will be stored and synchronized as GitHub Issues in your chosen repository.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Repository Input
                TextFormField(
                  controller: _repoController,
                  decoration: const InputDecoration(
                    labelText: 'GitHub Repository',
                    hintText: 'owner/repository',
                    prefixIcon: Icon(Icons.folder_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'e.g. etnt/mytodos',
                  ),
                  autocorrect: false,
                  validator: _validateRepo,
                ),
                const SizedBox(height: 16),

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
                      icon: Icon(_obscureToken ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscureToken = !_obscureToken),
                    ),
                  ),
                  autocorrect: false,
                  validator: _validateToken,
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
                            style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w500),
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
                            style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Action Buttons
                OutlinedButton.icon(
                  onPressed: _isTestingConnection ? null : _testConnection,
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
                  onPressed: settings.isLoading ? null : _saveSettings,
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

