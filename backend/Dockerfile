# Imagen de producción: sin root, sin herramientas de desarrollo.
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    NOTEMED_ENTORNO=produccion

WORKDIR /app
RUN useradd --create-home --uid 10001 notemed

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY alembic ./alembic
COPY alembic.ini ./

USER notemed
EXPOSE 8000

# Las migraciones se ejecutan como paso previo al despliegue:
#   alembic upgrade head
CMD ["uvicorn", "app.main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000"]
