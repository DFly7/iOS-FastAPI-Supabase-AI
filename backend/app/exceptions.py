"""Domain-specific exceptions. Register handlers in app/exception_handlers.py."""


class DomainError(Exception):
    """Base class for application errors (replace or extend per feature)."""

    pass
