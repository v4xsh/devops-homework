# Compute layer: one Ubuntu EC2 instance that installs nginx on first boot.

# Latest Canonical Ubuntu amd64 image (used only when var.ami_id is empty).
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-*-amd64-server-*"]
  }
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    student = "Vansh Dobhal"
    roll_no = "10099"
    project = var.project
  })
}

resource "aws_instance" "web" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id        # implicit dependency
  vpc_security_group_ids = [aws_security_group.web.id] # implicit dependency
  key_name               = var.key_name
  user_data              = local.user_data

  # EXPLICIT dependency: nothing in this block references the route table
  # association, but user_data runs `apt-get install nginx` on first boot and
  # needs a working internet route. depends_on makes Terraform finish the
  # IGW route + subnet association before the instance is launched.
  depends_on = [aws_route_table_association.public]

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = { Name = "${var.project}-web" }
}
