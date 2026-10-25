FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY pyproject.toml ./
COPY app ./app
RUN pip install --no-cache-dir .
COPY alembic.ini ./
COPY alembic ./alembic
COPY scripts/start.sh scripts/serve.py scripts/image_source.py ./scripts/
CMD ["sh", "scripts/start.sh"]
