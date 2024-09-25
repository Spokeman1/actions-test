##	LAB de PENTEST

## Para crear una infraestructura básica  de red en AWS utilizando Terraform, formada por dos instancias EC2 con acceso desde internet por los puertos 80,8080,443 y 22 (SSH limitado por un grupo de seguridad) y un load balancer, necesitamos los siguientes componentes: 
##•	Una VPC con un bloque CIDR especificado. 
##•	Dos subredes públicas dentro de la VPC para las instancias de EC2. 
##•	Una Puerta de enlace a Internet para permitir el acceso a Internet. 
##•	Tablas de enrutamiento para dirigir el tráfico desde las subredes a la Puerta de enlace a Internet. 
##•	Grupos de seguridad para permitir el tráfico en los puertos 80 (HTTP), 443 (HTTPS), 8080 (puerto HTTP alternativo) y 22 (SSH). 
##•	Dos instancias de EC2 dentro de las subredes, utilizando los grupos de seguridad.
##•	Un load balancer
## Este es el código TERRAFORM que crea esta infraestructura.

provider "aws" {
  region = "us-west-2" # Change to your preferred AWS region
}

resource "aws_vpc" "main" {
  cidr_block = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-gateway"
  }
}

resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "main-route-table"
  }
}

resource "aws_subnet" "public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = count.index == 0 ? "10.1.1.0/24" : "10.1.2.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index}"
  }
}

resource "aws_route_table_association" "route_association" {
  count          = length(aws_subnet.public_subnet.*.id)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.routetable.id
}

resource "aws_security_group" "web_sg" {
  name        = "web-security-group"
  description = "Allow inbound traffic on HTTP, HTTPS, alternative HTTP and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allows access from anywhere
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

resource "aws_instance" "web" {
  count                  = 2
  ami                    = "ami-0bdf93799014acdc4" # Change to an appropriate AMI for your region
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet[count.index].id
  security_groups        = [aws_security_group.web_sg.name]
  associate_public_ip_address = true

  tags = {
    Name = "web-instance-${count.index}"
  }
}

output "web_instance_public_ips" {
  value = aws_instance.web.*.public_ip
}

# Existing provider setup remains unchanged
# Existing VPC, Internet Gateway, Route Table, Subnets, and Associations remain unchanged

resource "aws_security_group" "web_sg" {
  name        = "web-security-group"
  description = "Allow inbound traffic on HTTP, HTTPS, and alternative HTTP"
  vpc_id      = aws_vpc.main.id

# Existing ingress rules for HTTP and HTTPS remain unchanged
# Update SSH ingress rule to restrict access
 ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["1.1.1.0/24"] # Replace with your IP range
  }
  
# Existing egress rule allowing all outbound traffic remains unchanged

tags = {
    Name = "web-sg"
  }
}

# Existing web instance configuration remains unchanged
# Remember to update the AMI if necessary

resource "aws_elb" "web_elb" {
  name               = "web-load-balancer"
  availability_zones = ["us-west-2a", "us-west-2b"] # Adjust to preferred AZs

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 443
    instance_protocol = "https"
    lb_port           = 443
    lb_protocol       = "https"
  }

  instances                   = aws_instance.web.*.id
  cross_zone_load_balancing   = true
  idle_timeout                = 60

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  tags = {
    Name = "web-elb"
  }
}

# Output for web instance public IPs remains unchanged
output "web_instance_public_ips" {
  value = aws_instance.web.*.public_ip
}

# Add an output for the load balancer DNS name
output "web_elb_dns_name" {
  value = aws_elb.web_elb.dns_name
}
