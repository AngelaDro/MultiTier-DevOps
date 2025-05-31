#!/bin/bash

# Exit immediately if any command fails
set -e

INVENTORY_FILE="hosts.ini"

echo "🔧 Installing Docker (if necessary)..."
ansible-playbook -i "$INVENTORY_FILE" install_docker.yml

echo "🛠️ Deploying MySQL..."
ansible-playbook -i "$INVENTORY_FILE" mysql.yml

echo "📦 Deploying Memcached..."
ansible-playbook -i "$INVENTORY_FILE" memcached.yml

echo "📦 Deploying RabbitMQ..."
ansible-playbook -i "$INVENTORY_FILE" rabbitmq.yml

echo "🚀 Deploying Tomcat..."
ansible-playbook -i "$INVENTORY_FILE" tomcat.yml

echo "🌐 Deploying Nginx..."
ansible-playbook -i "$INVENTORY_FILE" nginx.yml

echo "✅ Stack deployment completed successfully."
