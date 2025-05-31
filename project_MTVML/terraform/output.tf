output "instance_ips" {
  description = "Public IPs of all EC2 instances"
  value = {
    mysql     = aws_instance.mysql.public_ip
    memcached = aws_instance.memcached.public_ip
    rabbitmq  = aws_instance.rabbitmq.public_ip
    tomcat    = aws_instance.tomcat.public_ip
    nginx     = aws_instance.nginx.public_ip
  }
}
