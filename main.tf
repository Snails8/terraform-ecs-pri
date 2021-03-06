# CI/CD で使用 (無駄な使用を避けるためあえてコメントアウトしている)
#terraform {
#  backend "s3" {
#    bucket = "バケット名を指定"
#    key    = "terraform.tfstate"
#    region = "ap-northeast-1"
#
#  }
#  required_providers {
#    aws = {
#      source  = "hashicorp/aws"
#      version = "~> 3.27"
#    }
#  }
#  required_version = ">= 0.14.9"
#}

# provider の設定 ( provider は aws 専用ではなくGCPとかも使える)
provider "aws" {
  region = "ap-northeast-1"
}

# ========================================================
# Network 作成
#
# VPC, subnet(pub, pri), IGW, RouteTable, Route, RouteTableAssociation
# ========================================================
module "network" {
  source = "./module/network"
  app_name = var.APP_NAME
  azs      = var.azs
  vpc_cidr = var.vpc_cidr
}

# ========================================================
# Security Group
# ========================================================
module "security_group" {
  source   = "./module/security_group"
  app_name = var.APP_NAME
  vpc_cidr = var.vpc_cidr
  vpc_id   = module.network.vpc_id
  private_route_table  = module.network.route_table_private
  private_subnets      = module.network.private_subnet_ids
}

# ========================================================
# EC2 (vpc_id, subnet_id が必要)
# ========================================================
module "ec2" {
  source = "./module/ec2"
  app_name = var.APP_NAME
  vpc_id    = module.network.vpc_id
  public_subnet_id = module.network.public_subnet_ids[0]
  ssh_sg_id        = module.security_group.ssh_sg_id
}

# ========================================================
# ECS 作成
#
# ECS(service, cluster elb
# ========================================================
module "ecs" {
  source = "./module/ecs/app"
  app_name = var.APP_NAME
  vpc_id   = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  cluster_name = module.ecs_cluster.cluster_name
  # elb の設定
  target_group_arn               = module.elb.aws_lb_target_group
  # ECS のtask に関連付けるIAM の設定
  iam_role_task_execution_arn = module.iam.iam_role_task_execution_arn
  app_key = var.APP_KEY

  loki_user = var.LOKI_USER
  loki_pass = var.LOKI_PASS

  sg_list = [
    module.security_group.alb_sg_id,  # ALBの設定
    module.security_group.ecs_sg_id,
    module.security_group.redis_ecs_sg_id  # redis
  ]
}

# cluster 作成
module "ecs_cluster" {
  source   = "./module/ecs/cluster"
  app_name = var.APP_NAME
}

# ACM 発行
module "acm" {
  source   = "./module/acm"
  app_name = var.APP_NAME
  zone     = var.ZONE
  domain   = var.DOMAIN
}

# ELB の設定
module "elb" {
  source            = "./module/elb"
  app_name          = var.APP_NAME
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  alb_sg            = module.security_group.alb_sg_id

  domain = var.DOMAIN
  zone   = var.ZONE
  acm_id = module.acm.acm_id
}

# IAM 設定
# ECS-Agentが使用するIAMロール や タスク(=コンテナ)に付与するIAMロール の定義
module "iam" {
  source = "./module/iam"
  app_name = var.APP_NAME
}

# ========================================================
# RDS 作成
#
# [subnetGroup, securityGroup, RDS instance(postgreSQL)]
# ========================================================
# RDS (PostgreSQL)
module "rds" {
  source = "./module/rds"

  app_name = var.APP_NAME
  vpc_id   = module.network.vpc_id
  db_sg_id           = module.security_group.db_sg_id
  private_subnet_ids = module.network.private_subnet_ids

  database_name   = var.DB_NAME
  master_username = var.DB_MASTER_NAME
  master_password = var.DB_MASTER_PASS
}

# ========================================================
# Elasticache (Redis)
# ========================================================
module "elasticache" {
  source = "./module/elasticache"
  app_name = var.APP_NAME
  vpc_id = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  redis_sg_id        = module.security_group.redis_ecs_sg_id
}

# ========================================================
# SES : Simple Email Service
# メール送信に使用
# ========================================================
module "ses" {
  source = "./module/ses"
  domain = var.DOMAIN
  zone   = var.ZONE
}