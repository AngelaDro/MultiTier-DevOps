#!/bin/bash

set -e

# Step 1: Apply Terraform
echo "🚀 Start Terraform..."
terraform init
terraform apply -auto-approve

# Step 2: Get IP-address from output
echo "⏳ Get IP-address..."
mysql_ip=$(terraform output -raw instance_ips.mysql)
memcached_ip=$(terraform output -raw instance_ips.memcached)
rabbitmq_ip=$(terraform output -raw instance_ips.rabbitmq)
tomcat_ip=$(terraform output -raw instance_ips.tomcat)
nginx_ip=$(terraform output -raw instance_ips.nginx)

echo "🌍 MySQL:             $mysql_ip"
echo "🌍 Memcached:         $memcached_ip"
echo "🌍 RabbitMQ:          $rabbitmq_ip"
echo "🌍 Tomcat:            $tomcat_ip"
echo "🌍 Nginx:             $nginx_ip"

# Step 3: Wait for SSH access
echo "⌛ Waiting for SSH accessibility..."
for ip in $mysql_ip $memcached_ip $rabbitmq_ip $tomcat_ip $nginx_ip; do
  echo "🔐 Checking SSH for $ip..."
  until ssh -o StrictHostKeyChecking=no -i ~/.ssh/DevopsCourseKeys.pem ec2-user@$ip 'echo SSH OK'; do
    sleep 5
  done
done
echo "✅ SSH available to all instances."

# Step 4: Generate hosts.ini
echo "📝 Generating file hosts.ini..."
cat > hosts.ini <<EOF
[mysql]
$mysql_ip ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/DevopsCourseKeys.pem

[memcached]
$memcached_ip ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/DevopsCourseKeys.pem

[rabbitmq]
$rabbitmq_ip ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/DevopsCourseKeys.pem

[tomcat]
$tomcat_ip ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/DevopsCourseKeys.pem

[nginx]
$nginx_ip ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/DevopsCourseKeys.pem
EOF

echo "✅ The file hosts.ini has been created successfully."

# Step 5: Run Ansible playbooks
echo "📦 Starting Ansible with deploy_stack.sh..."
chmod +x deploy_stack.sh
./deploy_stack.sh

echo "🎉 Done! Infrastructure and applications have been deployed successfully."
