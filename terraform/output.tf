output "vm_public_ip" {
  value       = aws_instance.k8s_vm.public_ip
  description = "The dynamic public IP address allocated by AWS"
}