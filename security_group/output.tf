# ECSで使用
output "ecs_sg_id" {
  value = aws_security_group.ecs.id
}