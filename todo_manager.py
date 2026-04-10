import json
import os
from typing import List, Optional
from models import Todo


class TodoManager:
    def __init__(self, filename: str = "todos.json"):
        self.filename = filename
        self.todos: List[Todo] = []
        self.load()

    def load(self):
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
        with open(self.filename, 'w') as f:
            json.dump([todo.to_dict() for todo in self.todos], f, indent=2)

    def add_todo(self, header: str, body: str) -> Todo:
        priority = max([t.priority for t in self.todos], default=-1) + 1
        todo = Todo(header=header, body=body, priority=priority)
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
            self.save()

    def move_down(self, todo: Todo, todos_list: List[Todo]):
        current_idx = todos_list.index(todo)
        if current_idx < len(todos_list) - 1:
            next_todo = todos_list[current_idx + 1]
            todo.priority, next_todo.priority = next_todo.priority, todo.priority
            self.save()

    def delete_todo(self, todo: Todo):
        self.todos.remove(todo)
        self.save()

    def update_todo(self, todo: Todo, header: str, body: str):
        todo.header = header
        todo.body = body
        self.save()
