import uuid
from datetime import datetime
from typing import Optional


class Todo:
    def __init__(
        self,
        header: str,
        body: str,
        id: Optional[str] = None,
        created_date: Optional[str] = None,
        finished_date: Optional[str] = None,
        status: str = "active",
        priority: int = 0
    ):
        self.id = id or str(uuid.uuid4())
        self.header = header
        self.body = body
        self.created_date = created_date or datetime.now().isoformat()
        self.finished_date = finished_date
        self.status = status
        self.priority = priority

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "header": self.header,
            "body": self.body,
            "created_date": self.created_date,
            "finished_date": self.finished_date,
            "status": self.status,
            "priority": self.priority
        }

    @classmethod
    def from_dict(cls, data: dict) -> 'Todo':
        return cls(
            id=data["id"],
            header=data["header"],
            body=data["body"],
            created_date=data["created_date"],
            finished_date=data.get("finished_date"),
            status=data.get("status", "active"),
            priority=data.get("priority", 0)
        )

    def mark_done(self):
        self.status = "done"
        self.finished_date = datetime.now().isoformat()

    def mark_active(self):
        self.status = "active"
        self.finished_date = None
