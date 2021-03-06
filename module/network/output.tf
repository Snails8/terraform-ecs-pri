# 各種要素で使用
output "vpc_id" {
  value = aws_vpc.main.id
}

# ELB / EC2 で使用
output "public_subnet_ids" {
  value = aws_subnet.publics.*.id
}

# ECS/RDS/SG で使用
output "private_subnet_ids" {
  value = aws_subnet.privates.*.id
}

# sg(VPC endpoint) で使用
output "route_table_private" {
  value = aws_route.private[*]
}
