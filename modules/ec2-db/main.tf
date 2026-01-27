################################################################################
# EC2 DB Module - Oracle XE 21c via Docker Compose on Ubuntu
################################################################################
resource "aws_instance" "db" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.key_name
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = false

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  user_data_base64 = base64encode(templatefile("${path.module}/user_data.sh", {
    db_user               = var.db_user
    db_password           = var.db_password
    aws_region            = var.aws_region
    aws_access_key_id     = var.aws_access_key_id
    aws_secret_access_key = var.aws_secret_access_key
  }))

  tags = merge(var.tags, {
    Name     = "${var.environment}-CFW_Demo_DB"
    Role     = "Database"
    Database = "Oracle XE 21c (Docker)"
  })

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Associate Existing EIP with EC2 Instance
################################################################################
resource "aws_eip_association" "db" {
  instance_id   = aws_instance.db.id
  allocation_id = var.elastic_ip_allocation_id
}
