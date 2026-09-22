"""Tests for multi-repo issue backend configuration and switching."""

import os
import tempfile
import unittest
from unittest import mock

from repo_config import RepoConfig, RepoConfigStore
from todo_manager import TodoManager


class RepoConfigStoreTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.config_file = os.path.join(self.tmp.name, "repos.json")

    def tearDown(self):
        self.tmp.cleanup()

    def test_seeds_local_backend_when_no_env_or_file(self):
        store = RepoConfigStore(filename=self.config_file, env_github_repo=None, env_github_token=None)
        self.assertEqual(len(store.repos), 1)
        self.assertTrue(store.repos[0].is_local)
        self.assertEqual(store.active_name, "local")
        self.assertTrue(os.path.exists(self.config_file))

    def test_seeds_from_legacy_env_vars(self):
        store = RepoConfigStore(
            filename=self.config_file,
            env_github_repo="etnt/mytodos",
            env_github_token="tok",
        )
        names = [repo.name for repo in store.repos]
        self.assertEqual(names, ["local", "mytodos"])
        self.assertEqual(store.get("mytodos").repo, "etnt/mytodos")

    def test_persists_added_repos(self):
        store = RepoConfigStore(filename=self.config_file, env_github_repo=None, env_github_token=None)
        store.add_repo("work", "acme/widgets", token="secret")

        reloaded = RepoConfigStore(filename=self.config_file, env_github_repo=None, env_github_token=None)
        self.assertEqual([repo.name for repo in reloaded.repos], ["local", "work"])
        self.assertEqual(reloaded.get("work").repo, "acme/widgets")
        self.assertEqual(reloaded.get("work").token, "secret")

    def test_active_backend_persists(self):
        store = RepoConfigStore(filename=self.config_file, env_github_repo=None, env_github_token=None)
        store.add_repo("work", "acme/widgets")
        store.set_active("work")

        reloaded = RepoConfigStore(filename=self.config_file, env_github_repo=None, env_github_token=None)
        self.assertEqual(reloaded.active_name, "work")
        self.assertEqual(reloaded.get_active().repo, "acme/widgets")

    def test_add_repo_validation(self):
        store = RepoConfigStore(filename=self.config_file, env_github_repo=None, env_github_token=None)
        with self.assertRaises(ValueError):
            store.add_repo("", "acme/widgets")
        with self.assertRaises(ValueError):
            store.add_repo("work", "not-a-slug")
        store.add_repo("work", "acme/widgets")
        with self.assertRaises(ValueError):
            store.add_repo("work", "acme/other")

    def test_remove_repo_keeps_at_least_one(self):
        store = RepoConfigStore(filename=self.config_file, env_github_repo=None, env_github_token=None)
        with self.assertRaises(ValueError):
            store.remove_repo("local")

    def test_remove_active_repo_reassigns_active(self):
        store = RepoConfigStore(filename=self.config_file, env_github_repo=None, env_github_token=None)
        store.add_repo("work", "acme/widgets")
        store.set_active("work")
        store.remove_repo("work")
        self.assertEqual(store.active_name, "local")
        self.assertEqual(len(store.repos), 1)

    def test_token_falls_back_to_env(self):
        store = RepoConfigStore(filename=self.config_file, env_github_repo=None, env_github_token="envtok")
        self.assertEqual(store.token_for(RepoConfig(name="x", repo="a/b")), "envtok")
        self.assertEqual(store.token_for(RepoConfig(name="y", repo="a/b", token="own")), "own")

    def test_corrupt_file_reseeds(self):
        with open(self.config_file, "w") as f:
            f.write("{ not valid json")


class TodoManagerMultiBackendTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.config_file = os.path.join(self.tmp.name, "repos.json")
        self.todos_file = os.path.join(self.tmp.name, "todos.json")
        self.store = RepoConfigStore(
            filename=self.config_file, env_github_repo=None, env_github_token=None
        )

    def tearDown(self):
        self.tmp.cleanup()

    def test_local_backend_roundtrip(self):
        manager = TodoManager(filename=self.todos_file, repo_store=self.store)
        manager.add_todo("First", "body one")
        manager.add_todo("Second", "body two")

        reloaded = TodoManager(filename=self.todos_file, repo_store=self.store)
        self.assertEqual([t.header for t in reloaded.get_all_todos()], ["First", "Second"])

    def test_switch_backend_updates_active_repo(self):
        self.store.add_repo("work", "acme/widgets", token="tok1")
        manager = TodoManager(filename=self.todos_file, repo_store=self.store)
        self.assertIsNone(manager.github_repo)

        with mock.patch.object(TodoManager, "_request", return_value=[]):
            manager.set_active_repo("work")

        self.assertEqual(manager.github_repo, "acme/widgets")
        self.assertEqual(self.store.active_name, "work")
        self.assertEqual(manager._active_token(), "tok1")

    def test_switch_backend_without_token_is_rejected(self):
        self.store.add_repo("work", "acme/widgets", token=None)
        manager = TodoManager(filename=self.todos_file, repo_store=self.store)
        with self.assertRaises(ValueError):
            manager.set_active_repo("work")
        self.assertIsNone(manager.github_repo)
        self.assertEqual(self.store.active_name, "local")

    def test_headers_use_active_repo_token(self):
        self.store.add_repo("work", "acme/widgets", token="tok1")
        manager = TodoManager(filename=self.todos_file, repo_store=self.store)

        with mock.patch.object(TodoManager, "_request", return_value=[]):
            manager.set_active_repo("work")
        headers = manager._headers()
        self.assertEqual(headers["Authorization"], "Bearer tok1")

        with mock.patch.object(TodoManager, "_request", return_value=[]):
            manager.set_active_repo("local")
        self.assertNotIn("Authorization", manager._headers())

    def test_github_backend_missing_token_raises(self):
        self.store.add_repo("work", "acme/widgets", token=None)
        self.store.set_active("work")
        with self.assertRaises(RuntimeError):
            TodoManager(filename=self.todos_file, repo_store=self.store)


class RepoConfigTest(unittest.TestCase):
    def test_roundtrip(self):
        repo = RepoConfig(name="work", repo="acme/widgets", token="t")
        restored = RepoConfig.from_dict(repo.to_dict())
        self.assertEqual(restored.name, "work")
        self.assertEqual(restored.repo, "acme/widgets")
        self.assertEqual(restored.token, "t")
        self.assertFalse(restored.is_local)

    def test_local_config(self):
        repo = RepoConfig(name="local", repo=None)
        self.assertTrue(repo.is_local)
        restored = RepoConfig.from_dict(repo.to_dict())
        self.assertTrue(restored.is_local)


if __name__ == "__main__":
    unittest.main()
