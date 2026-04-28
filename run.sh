#!/bin/sh
exec gunicorn \
  --bind 0.0.0.0:5500 \
  --worker-tmp-dir /tmp \
  app:app