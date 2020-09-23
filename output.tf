output "server_public_ip4" {
  value = aws_instance.jitsi-instance.public_ip
}
output "server_public_ip6" {
  value = aws_instance.jitsi-instance.ipv6_addresses
}
