output "dns_name" {
  description = "DNS name of the Global Accelerator"
  value       = aws_globalaccelerator_accelerator.this.dns_name
}

output "ip_addresses" {
  description = "Static IPv4 addresses assigned to the Global Accelerator"
  value       = aws_globalaccelerator_accelerator.this.ip_sets[0].ip_addresses
}