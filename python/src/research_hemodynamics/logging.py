"""Standard logging helpers for the Python hemodynamics package."""

from __future__ import annotations

import logging
from typing import Any

PACKAGE_LOGGER_NAME = "research_hemodynamics"
_HANDLER_MARKER = "_research_hemodynamics_cli_handler"
_RESERVED_LOG_RECORD_KEYS = set(logging.makeLogRecord({}).__dict__)
_RESERVED_LOG_RECORD_KEYS.update({"message", "asctime"})


def get_logger(name: str | None = None) -> logging.Logger:
    return logging.getLogger(name or PACKAGE_LOGGER_NAME)


def parse_log_level(level: str) -> int:
    normalized = level.strip().upper()
    value = getattr(logging, normalized, None)
    if not isinstance(value, int):
        raise ValueError(f"unknown log level {level!r}; expected DEBUG, INFO, WARNING, ERROR, or CRITICAL")
    return value


def configure_logging(level: str = "WARNING") -> None:
    """Configure package logs for CLI entrypoints without touching stdout."""

    parsed = parse_log_level(level)
    logger = logging.getLogger(PACKAGE_LOGGER_NAME)
    logger.handlers = [handler for handler in logger.handlers if not getattr(handler, _HANDLER_MARKER, False)]
    handler = logging.StreamHandler()
    setattr(handler, _HANDLER_MARKER, True)
    handler.setFormatter(logging.Formatter("%(levelname)s %(name)s %(message)s"))
    logger.addHandler(handler)
    logger.setLevel(parsed)
    logger.propagate = False


def event_fields(**fields: Any) -> dict[str, Any]:
    """Return non-null LogRecord extras while avoiding stdlib field collisions."""

    return {key: value for key, value in fields.items() if value is not None and key not in _RESERVED_LOG_RECORD_KEYS}
