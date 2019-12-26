provider "aws" {
  region  = "eu-west-2"
  profile = "terraform"
}

terraform {
  backend "s3" {
    # Bucket name
    bucket = "drazvt-terraform-state"
    key = "cctv-app/stage/terraform.tfstate"
    region = "eu-west-2"

    # DybamoDB table name
    dynamodb_table = "drazvt-terraform-locks"
    encrypt = true
    profile = "terraform"
  }
}

#VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "cctv-vpc"
  }
}

#Subnet
resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

#Public Route Table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

#Associate subnet with public route table
resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_eip" "main" {
  vpc = true
  instance = aws_instance.server01.id
  associate_with_private_ip = aws_instance.server01.private_ip
  depends_on = [aws_internet_gateway.gw]
}


#Security Group
resource "aws_security_group" "sg01" {
  name = "allow_ssh_ftp"
  vpc_id = aws_vpc.main.id
}

#Security group rule ssh in
resource "aws_security_group_rule" "ssh" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["90.255.235.195/32"]
  security_group_id = aws_security_group.sg01.id
}

#Security group rule ftp in
resource "aws_security_group_rule" "ftp" {
  type = "ingress"
  from_port = 21
  to_port = 21
  protocol = "tcp"
  cidr_blocks = ["90.255.235.195/32"]
  security_group_id = aws_security_group.sg01.id
}

resource "aws_security_group_rule" "allow_all" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg01.id
}



#Get ID for Amazon Linux 2 AMI 
data "aws_ami" "al2" {
  most_recent = true

  filter {
      name = "name"
      values = ["amzn2-ami-hvm-2.0.????????.?-x86_64-gp2"]
  }
  filter {
      name = "virtualization-type"
      values = ["hvm"]
  }
  owners = ["amazon"]
}

#IAM role for instance
resource "aws_iam_role" "role" {
  name = "ftp_to_s3"
    #Sets trust relationships
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Principal": {
        "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
    }
    ]
}
EOF
}
#Create IAM policy 
resource "aws_iam_policy" "policy" {
  name        = "ftp_to_s3"
  description = "Access from ftp server to s3"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "*"
        }
    ]
}
EOF
}

#Atach new IAM policy to the
resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

#IAM instance profile to atach ftp_to_s3 role
resource "aws_iam_instance_profile" "profile01" {
  name = "ftp_to_s3"
  role = "ftp_to_s3"
}

# Create S3 bucket for cctv
resource "aws_s3_bucket" "cctv" {
  bucket = "drazvt-cctv"
  acl = "private"
  force_destroy = true
  lifecycle_rule {
    enabled = true
    expiration {
      days = 14
    }
  }
}

# S3 bucket policy, allow list + read from specified ips

resource "aws_s3_bucket_policy" "cctv" {
  bucket = aws_s3_bucket.cctv.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Id": "Policyxxxx961",
    "Statement": [
        {
            "Sid": "IpAllowAccess",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::drazvt-cctv",
                "arn:aws:s3:::drazvt-cctv/*"
            ],
            "Condition": {
                "IpAddress": {
                    "aws:SourceIp": [
                        "90.255.235.195/32"
                    ]
                }
            }
        }
    ]
}
POLICY
}





# EC2
resource "aws_instance" "server01" {
  ami = data.aws_ami.al2.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet1.id
  key_name = "eulondonkp"
  iam_instance_profile = "ftp_to_s3"
  user_data = file("update_install.sh")
  vpc_security_group_ids = [aws_security_group.sg01.id]
}


#Output values
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of your selected VPC"
}

output "instance_ips" {
  value = aws_eip.main.public_ip
}







