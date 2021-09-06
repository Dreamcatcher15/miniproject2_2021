data "aws_ami" "amazon" { #pull automatic ami
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

resource "aws_instance" "my-instance" { #local exec ec2
  ami           = data.aws_ami.amazon.id
  instance_type = "t2.micro"

  provisioner "local-exec" {
    command = "echo ${aws_instance.my-instance.public_ip} >> private_ip.txt" #copy public ip into that file in the local machine
  }
  tags = {
    "Name" = element(var.tags, 1)
  }
}

variable "tags" {
  type    = list(any)
  default = ["sunnyec2", "kookyec2", "sunshineec2"]
}


resource "aws_key_pair" "my-key" {
  key_name   = "devops14-tf-key-1"
  public_key = file("${path.module}/my_public_key.txt") #key pair

}

resource "aws_instance" "remote-ec2" { #use key pair for ec2 remote exec
  ami           = data.aws_ami.amazon.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.my-key.id
  vpc_security_group_ids = [aws_security_group.my-sg.id]

provisioner "remote-exec" { 
  inline = [
      "sudo yum install -y httpd" ,
      "cd /var/www/html" ,
      "sudo wget https://devops14-mini-project.s3.amazonaws.com/default/index-default.html",
      "sudo wget https://devops14-mini-project.s3.amazonaws.com/default/mycar.jpeg",
      "sudo mv index-default.html index.html",
      "sudo systemctl enable httpd --now"
    ]

connection { #terraform can do ssh into that remote box
  type        = "ssh"
  user        = "ec2-user"
  private_key = file("./private_key.pem")
  host        = self.public_ip

    }
  }
}
resource "aws_security_group" "my-sg" {
  name = "remote-ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_vpc" "my-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "terraform-vpc"
  }
}
resource "aws_internet_gateway" "my-ig" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    Name = "terraform-ig"
  }
}
resource "aws_subnet" "my-public-subnet" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = "10.0.0.0/24"
  tags = {
    Name = "terraform-public-subnet"
  }
}
resource "aws_subnet" "my-private-subnet" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "terraform-private-subnet"
  }
}
resource "aws_route_table" "my-rt" {
  vpc_id = aws_vpc.my-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-ig.id
  }
  tags = {
    Name = "terraform-public-rt"
  }
}
resource "aws_route_table" "my-private-rt" {
  vpc_id = aws_vpc.my-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.my-nat-gw.id
  }
  tags = {
    Name = "terraform-private-rt"
  }
}
resource "aws_route_table_association" "public-association" {
  subnet_id      = aws_subnet.my-public-subnet.id
  route_table_id = aws_route_table.my-rt.id
}
resource "aws_route_table_association" "private-association" {
  subnet_id      = aws_subnet.my-private-subnet.id
  route_table_id = aws_route_table.my-private-rt.id
}
resource "aws_eip" "terraform-eip" {
  vpc = true
  tags = {
    Name = "terraform-eip"
  }
}
resource "aws_nat_gateway" "my-nat-gw" {
  allocation_id = aws_eip.terraform-eip.id
  subnet_id     = aws_subnet.my-private-subnet.id
  tags = {
    Name = "terraform-nat-gw"
  }
}

resource "aws_security_group" "regular-sg" {
  name = "devops14-project-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


}
locals {
  time = formatdate("DD MM YYYY hh:mm ZZZ", timestamp())
}
output "timestamp" {
  value = local.time
}