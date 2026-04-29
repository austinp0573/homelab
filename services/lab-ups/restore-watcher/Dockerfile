FROM python:3.13-alpine

RUN apk add --no-cache nut

WORKDIR /app
COPY watcher.py /app/watcher.py

ENTRYPOINT ["python", "/app/watcher.py"]
