import json
import logging


def log_save_step(
    logger: logging.Logger,
    step: str,
    elapsed_seconds: float,
    status: str,
    failure_reason: str | None,
) -> None:
    logger.info(json.dumps({
        "event": "content_save_step",
        "step": step,
        "elapsed_seconds": round(elapsed_seconds, 3),
        "status": status,
        "failure_reason": failure_reason,
    }))
