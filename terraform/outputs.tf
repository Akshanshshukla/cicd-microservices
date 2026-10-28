output "ecr_repository_urls" {
  value = { orders = aws_ecr_repository.orders.repository_url, catalog = aws_ecr_repository.catalog.repository_url, gateway = aws_ecr_repository.gateway.repository_url }
}
output "ecs_cluster_name" { value = aws_ecs_cluster.demo.name }
output "ecs_service_name" { value = aws_ecs_service.demo.name }
output "allowed_cidr" { value = var.allowed_cidr }
