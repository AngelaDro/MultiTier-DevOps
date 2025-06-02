#!/bin/bash

set -e

# Step 1: Apply Terraform
echo "🚀 Starting Terraform..."
terraform init
terraform apply -auto-approve

# Step 2: Get IP-address from output
echo "⏳ Getting IP-addresses..."
mysql_ip=$(terraform output -raw server_public_ips.mysql)
memcached_ip=$(terraform output -raw server_public_ips.memcached)
rabbitmq_ip=$(terraform output -raw server_public_ips.rabbitmq)
tomcat_ip=$(terraform output -raw server_public_ips.tomcat)
nginx_ip=$(terraform output -raw server_public_ips.nginx)

echo "🌍 MySQL:             $mysql_ip"
echo "🌍 Memcached:         $memcached_ip"
echo "🌍 RabbitMQ:          $rabbitmq_ip"
echo "🌍 Tomcat:            $tomcat_ip"
echo "🌍 Nginx:             $nginx_ip"

# Step 3: Wait for SSH access
echo "⌛ Waiting for SSH accessibility..."
for ip in $mysql_ip $memcached_ip $rabbitmq_ip $tomcat_ip $nginx_ip; do
  echo "🔐 Checking SSH for $ip..."
  until ssh -o StrictHostKeyChecking=no -i ~/.ssh/DevopsCourseKeys.pem ubuntu@$ip 'echo SSH OK'; do
    sleep 5
  done
done
echo "✅ SSH available to all instances."

# Step 4: Use existing Ansible inventory
echo "📝 Using existing Ansible inventory from ../ansible/hosts..."

# Step 5: Run Ansible playbook
echo "📦 Starting Ansible with site.yml..."
ansible-playbook -i ../ansible/hosts ../ansible/site.yml

echo "🎉 Done! Infrastructure and applications have been deployed successfully."