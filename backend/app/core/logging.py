import json
import logging


class _UnhandledErrorFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        if record.exc_info and record.exc_info[0] is not None:
            record.msg = json.dumps({
                "event": "unhandled_error",
                "exception_type": record.exc_info[0].__name__,
            })
            record.args = ()
            record.exc_info = None
            record.exc_text = None
            record.stack_info = None
        return True


_unhandled_error_filter = _UnhandledErrorFilter()


def configure_logging() -> None:
    # Keep HTTP library logs disabled; they can include sensitive request URLs.
    logger = logging.getLogger("app")
    logger.setLevel(logging.INFO)
    logger.propagate = False
    if not logger.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s [%(name)s] %(message)s"))
        logger.addHandler(handler)

    logging.getLogger("uvicorn.error").addFilter(_unhandled_error_filter)
