#!/bin/bash
set -e

echo "✅ Creating external Docker network (if not exists)..."
docker network inspect jenkins >/dev/null 2>&1 || docker network create jenkins

echo "✅ Preparing volume directory..."
mkdir -p data
chown -R 1000:1000 data

echo "✅ Checking for SSL keystore..."
if [ ! -f certs/keystore.jks ]; then
  echo "⚠️  keystore.jks not found. Generating..."
  bash create_keystore.sh
else
  echo "✅ keystore.jks already exists."
fi

echo "✅ Setting permissions for keystore..."
chown 1000:1000 certs/keystore.jks
chmod 644 certs/keystore.jks

echo "✅ Building Jenkins image..."
docker compose build

echo "✅ Starting Jenkins..."
docker compose up -d --remove-orphans