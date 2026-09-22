import logging


def configure_logging() -> None:
    # Configure only application logs; HTTP libraries can log sensitive request URLs.
    logger = logging.getLogger("app")
    logger.setLevel(logging.INFO)
    logger.propagate = False
    if not logger.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s [%(name)s] %(message)s"))
        logger.addHandler(handler)
