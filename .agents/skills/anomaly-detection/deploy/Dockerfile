FROM python:3.11-slim
WORKDIR /app
COPY pyproject.toml README.md ./
COPY src ./src
RUN python -m pip install --no-cache-dir -U pip && python -m pip install --no-cache-dir -e '.[api]'
COPY configs ./configs
EXPOSE 8000
CMD ["uvicorn", "anomaly_detection.api:app", "--host", "0.0.0.0", "--port", "8000"]
