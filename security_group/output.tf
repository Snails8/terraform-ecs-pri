# ECSで使用
output "ecs_sg_id" {
  value = aws_security_group.ecs.id
}

# redis で使用
output "redis_ecs_sg_id" {
  value = aws_security_group.redis_ecs.id
}