#!/bin/sh
set -eu
exec gunicorn --bind "0.0.0.0:5500" app:app