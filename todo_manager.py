import json
import os
import urllib.error
import urllib.request
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from models import Todo


class TodoManager:
    def __init__(self, filename: str = "todos.json"):
        self.filename = filename
        self.github_repo = os.environ.get("TODO_GITHUB_REPO")
        self.github_token = os.environ.get("GITHUB_TOKEN")
        self.todos: List[Todo] = []
        self.load()

    def load(self):
        if self.github_repo:
            try:
                self.todos = self._load_from_github()
            except (urllib.error.URLError, json.JSONDecodeError, KeyError, RuntimeError):
                self.todos = []
            return

        if os.path.exists(self.filename):
            try:
                with open(self.filename, 'r') as f:
                    data = json.load(f)
                    self.todos = [Todo.from_dict(item) for item in data]
            except (json.JSONDecodeError, KeyError):
                self.todos = []
        else:
            self.todos = []

    def save(self):
        if self.github_repo:
            return
        with open(self.filename, 'w') as f:
            json.dump([todo.to_dict() for todo in self.todos], f, indent=2)

    def add_todo(self, header: str, body: str) -> Todo:
        priority = max([t.priority for t in self.todos], default=-1) + 1
        todo = Todo(header=header, body=body, priority=priority)
        if self.github_repo:
            created_issue = self._create_issue(todo)
            todo.id = str(created_issue["number"])
            todo.created_date = self._normalize_timestamp(created_issue["created_at"])
            todo.finished_date = self._normalize_timestamp(created_issue.get("closed_at"))
            todo.status = "done" if created_issue.get("state") == "closed" else "active"
        self.todos.append(todo)
        self.save()
        return todo

    def get_active_todos(self) -> List[Todo]:
        return sorted(
            [t for t in self.todos if t.status == "active"],
            key=lambda x: x.priority
        )

    def get_done_todos(self) -> List[Todo]:
        return sorted(
            [t for t in self.todos if t.status == "done"],
            key=lambda x: x.priority
        )

    def get_all_todos(self) -> List[Todo]:
        return sorted(self.todos, key=lambda x: x.priority)

    def toggle_status(self, todo: Todo):
        if self.github_repo:
            state = "closed" if todo.status == "active" else "open"
            self._patch_issue(self._issue_number(todo), {"state": state})
            self.load()
        else:
            if todo.status == "active":
                todo.mark_done()
            else:
                todo.mark_active()
            self.save()

    def move_up(self, todo: Todo, todos_list: List[Todo]):
        current_idx = todos_list.index(todo)
        if current_idx > 0:
            prev_todo = todos_list[current_idx - 1]
            todo.priority, prev_todo.priority = prev_todo.priority, todo.priority
            if self.github_repo:
                self._patch_issue(
                    self._issue_number(todo),
                    {"body": self._build_issue_body(todo.body, {"priority": todo.priority, "deleted": False})}
                )
                self._patch_issue(
                    self._issue_number(prev_todo),
                    {"body": self._build_issue_body(prev_todo.body, {"priority": prev_todo.priority, "deleted": False})}
                )
            self.save()

    def move_down(self, todo: Todo, todos_list: List[Todo]):
        current_idx = todos_list.index(todo)
        if current_idx < len(todos_list) - 1:
            next_todo = todos_list[current_idx + 1]
            todo.priority, next_todo.priority = next_todo.priority, todo.priority
            if self.github_repo:
                self._patch_issue(
                    self._issue_number(todo),
                    {"body": self._build_issue_body(todo.body, {"priority": todo.priority, "deleted": False})}
                )
                self._patch_issue(
                    self._issue_number(next_todo),
                    {"body": self._build_issue_body(next_todo.body, {"priority": next_todo.priority, "deleted": False})}
                )
            self.save()

    def delete_todo(self, todo: Todo):
        if self.github_repo:
            self._patch_issue(
                self._issue_number(todo),
                {
                    "state": "closed",
                    "body": self._build_issue_body(todo.body, {"priority": todo.priority, "deleted": True}),
                }
            )
            self.load()
            return

        self.todos.remove(todo)
        self.save()

    def update_todo(self, todo: Todo, header: str, body: str):
        todo.header = header
        todo.body = body
        if self.github_repo:
            self._patch_issue(
                self._issue_number(todo),
                {
                    "title": header,
                    "body": self._build_issue_body(body, {"priority": todo.priority, "deleted": False}),
                }
            )
        self.save()

    def _headers(self) -> Dict[str, str]:
        headers = {
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        if self.github_token:
            headers["Authorization"] = f"Bearer {self.github_token}"
        return headers

    def _request(self, method: str, path: str, payload: Optional[Dict] = None):
        if not self.github_repo:
            raise RuntimeError("GitHub repo is not configured")

        if not self.github_token:
            raise RuntimeError("GITHUB_TOKEN is required when TODO_GITHUB_REPO is set")

        data = json.dumps(payload).encode("utf-8") if payload is not None else None
        request = urllib.request.Request(
            url=f"https://api.github.com{path}",
            data=data,
            headers=self._headers(),
            method=method,
        )
        with urllib.request.urlopen(request) as response:
            return json.loads(response.read().decode("utf-8"))

    def _list_issues(self) -> List[Dict]:
        repo = self.github_repo
        page = 1
        issues: List[Dict] = []
        while True:
            chunk = self._request(
                "GET",
                f"/repos/{repo}/issues?state=all&per_page=100&page={page}",
            )
            if not chunk:
                break
            issues.extend(chunk)
            if len(chunk) < 100:
                break
            page += 1
        return [issue for issue in issues if "pull_request" not in issue]

    def _load_from_github(self) -> List[Todo]:
        todos: List[Todo] = []
        for issue in self._list_issues():
            body_text, metadata = self._parse_issue_body(issue.get("body") or "")
            if metadata.get("deleted"):
                continue

            status = "done" if issue.get("state") == "closed" else "active"
            created_date = self._normalize_timestamp(issue["created_at"])
            finished_date = self._normalize_timestamp(issue.get("closed_at"))
            priority = int(metadata.get("priority", issue["number"]))

            todos.append(
                Todo(
                    id=str(issue["number"]),
                    header=issue["title"],
                    body=body_text,
                    created_date=created_date,
                    finished_date=finished_date,
                    status=status,
                    priority=priority,
                )
            )

        return sorted(todos, key=lambda x: x.priority)

    def _create_issue(self, todo: Todo) -> Dict:
        body = self._build_issue_body(todo.body, {"priority": todo.priority, "deleted": False})
        return self._request(
            "POST",
            f"/repos/{self.github_repo}/issues",
            {"title": todo.header, "body": body},
        )

    def _patch_issue(self, issue_number: int, payload: Dict):
        self._request(
            "PATCH",
            f"/repos/{self.github_repo}/issues/{issue_number}",
            payload,
        )

    def _issue_number(self, todo: Todo) -> int:
        return int(todo.id)

    def _parse_issue_body(self, issue_body: str) -> Tuple[str, Dict]:
        marker = "<!-- todo-meta:"
        marker_idx = issue_body.rfind(marker)
        if marker_idx == -1:
            return issue_body, {}

        metadata_part = issue_body[marker_idx + len(marker):]
        end_marker_idx = metadata_part.find("-->")
        if end_marker_idx == -1:
            return issue_body, {}

        raw_metadata = metadata_part[:end_marker_idx].strip()
        try:
            metadata = json.loads(raw_metadata) if raw_metadata else {}
        except json.JSONDecodeError:
            metadata = {}

        body = issue_body[:marker_idx].rstrip()
        return body, metadata

    def _build_issue_body(self, body: str, metadata: Dict) -> str:
        metadata_blob = json.dumps(metadata, separators=(",", ":"))
        if body:
            return f"{body.rstrip()}\n\n<!-- todo-meta: {metadata_blob} -->"
        return f"<!-- todo-meta: {metadata_blob} -->"

    def _normalize_timestamp(self, value: Optional[str]) -> Optional[str]:
        if not value:
            return None

        if value.endswith("Z"):
            value = value[:-1] + "+00:00"

        try:
            return datetime.fromisoformat(value).isoformat()
        except ValueError:
            return value
