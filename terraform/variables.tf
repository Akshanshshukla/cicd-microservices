variable "aws_region" {
  description = "AWS region for the demo."
  type = string
  default = "us-east-1"
}
variable "project_name" {
  type = string
  default = "portfolio-microservices"
}
variable "image_tag" {
  description = "Tag present in all three ECR repositories (for example, latest)."
  type = string
  default = "latest"
}
variable "desired_count" {
  description = "Set to 1 only after pushing the three images. Set to 0 to stop compute while retaining infrastructure."
  type = number
  default = 0
}
variable "allowed_cidr" {
  description = "IPv4 CIDR allowed to call the public demo endpoint. Set to your own public IP with /32."
  type = string
  default = "127.0.0.1/32"
}
