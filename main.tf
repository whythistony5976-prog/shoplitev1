terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy the S3 bucket."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used for bucket naming and tagging."
  type        = string
  default     = "shoplite"
}

resource "aws_s3_bucket" "shoplite_state" {
  bucket = "${var.project_name}-terraform-state"

  tags = {
    Name        = "${var.project_name}-terraform-state"
    Environment = "production"
  }
}