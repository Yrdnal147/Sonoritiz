#!/bin/bash

echo "Building project..."
python3 -m pip install -r requirements.txt

echo "Apply committed migrations..."
python3 manage.py migrate --noinput

echo "Collect static files..."
python3 manage.py collectstatic --noinput
