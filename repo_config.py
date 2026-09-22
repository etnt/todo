import json
import os
from typing import List, Optional

DEFAULT_REPO_CONFIG_FILE = "repos.json"
LOCAL_BACKEND_NAME = "local"


class RepoConfig:
    """A single issue backend: either a GitHub repo or the local JSON store."""

    def __init__(self, name: str, repo: Optional[str], token: Optional[str] = None):
        self.name = name
        self.repo = repo  # "owner/repo" or None for local JSON storage
        self.token = token

    @property
    def is_local(self) -> bool:
        return self.repo is None

    def to_dict(self) -> dict:
        return {"name": self.name, "repo": self.repo, "token": self.token or ""}

    @classmethod
    def from_dict(cls, data: dict) -> "RepoConfig":
        repo = data.get("repo")
        return cls(
            name=data["name"],
            repo=repo if repo else None,
            token=data.get("token") or None,
        )


class RepoConfigStore:
    """Persists the list of configured issue backends in a JSON file."""

    def __init__(
        self,
        filename: str = DEFAULT_REPO_CONFIG_FILE,
        env_github_repo: Optional[str] = None,
        env_github_token: Optional[str] = None,
    ):
        self.filename = filename
        self.env_github_repo = (
            env_github_repo
            if env_github_repo is not None
            else os.environ.get("TODO_GITHUB_REPO")
        )
        self.env_github_token = (
            env_github_token
            if env_github_token is not None
            else os.environ.get("GITHUB_TOKEN")
        )
        self.repos: List[RepoConfig] = []
        self.active_name: Optional[str] = None
        self.load()

    def load(self):
        self.repos = []
        self.active_name = None
        if os.path.exists(self.filename):
            try:
                with open(self.filename, "r") as f:
                    data = json.load(f)
                self.repos = [RepoConfig.from_dict(item) for item in data.get("repos", [])]
                self.active_name = data.get("active")
            except (json.JSONDecodeError, KeyError, TypeError):
                self.repos = []
                self.active_name = None

        if not self.repos:
            self._seed_defaults()

        if not any(repo.name == self.active_name for repo in self.repos):
            self.active_name = self.repos[0].name

    def _seed_defaults(self):
        """Seed the config from the legacy TODO_GITHUB_REPO/GITHUB_TOKEN env vars."""
        if self.env_github_repo:
            self.repos = [
                RepoConfig(name=LOCAL_BACKEND_NAME, repo=None),
                RepoConfig(
                    name=self._default_name(self.env_github_repo),
                    repo=self.env_github_repo,
                ),
            ]
        else:
            self.repos = [RepoConfig(name=LOCAL_BACKEND_NAME, repo=None)]
        self.save()

    @staticmethod
    def _default_name(repo_slug: str) -> str:
        return repo_slug.split("/")[-1] or repo_slug

    def save(self):
        with open(self.filename, "w") as f:
            json.dump(
                {
                    "active": self.active_name,
                    "repos": [repo.to_dict() for repo in self.repos],
                },
                f,
                indent=2,
            )

    def get(self, name: str) -> Optional[RepoConfig]:
        for repo in self.repos:
            if repo.name == name:
                return repo
        return None

    def get_active(self) -> Optional[RepoConfig]:
        return self.get(self.active_name) if self.active_name else None

    def set_active(self, name: str):
        repo = self.get(name)
        if repo is None:
            raise ValueError(f"Unknown repo backend: {name}")
        self.active_name = repo.name
        self.save()

    def add_repo(self, name: str, repo_slug: str, token: Optional[str] = None) -> RepoConfig:
        name = (name or "").strip()
        repo_slug = (repo_slug or "").strip()
        if not name:
            raise ValueError("Backend name must not be empty")
        if self.get(name) is not None:
            raise ValueError(f"A backend named '{name}' already exists")
        if "/" not in repo_slug:
            raise ValueError("Repo must be in 'owner/name' format")
        new_repo = RepoConfig(name=name, repo=repo_slug, token=token)
        self.repos.append(new_repo)
        self.save()
        return new_repo

    def remove_repo(self, name: str):
        repo = self.get(name)
        if repo is None:
            raise ValueError(f"Unknown repo backend: {name}")
        if len(self.repos) <= 1:
            raise ValueError("At least one backend must remain configured")

        self.repos.remove(repo)
        if self.active_name == repo.name:
            self.active_name = self.repos[0].name
        self.save()

    def token_for(self, repo: RepoConfig) -> Optional[str]:
        """Token for a backend: its own token, else the GITHUB_TOKEN env var."""
        if repo.token:
            return repo.token
        return self.env_github_token or os.environ.get("GITHUB_TOKEN")