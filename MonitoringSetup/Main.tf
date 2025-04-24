provider "aws" {
  region = "us-east-1"  # Change to your region
}

resource "aws_instance" "web" {
  ami           = "ami-0c2b8ca1dad447f8a" # Amazon Linux 2 AMI (check for your region)
  instance_type = "t2.micro"
  key_name      = "your-key-name"         # Replace with your key pair name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd git
              systemctl enable httpd
              systemctl start httpd
              cd /var/www/html
              git clone https://github.com/startbootstrap/startbootstrap-landing-page.git temp
              cp -r temp/* .
              rm -rf temp
            EOF

  tags = {
    Name = "ApacheWebServer"
  }

  vpc_security_group_ids = [aws_security_group.web_sg.id]
}

resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Allow SSH and HTTP"
  vpc_id      = data.aws_vpc.default.id

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
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_sns_topic" "alarm_topic" {
  name = "ec2-monitoring-topic"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alarm_topic.arn
  protocol  = "email"
  endpoint  = "subhagankiran21@gmail.com"  # Change this to your actual email
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "HighCPUUsage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "This alarm triggers if CPU is above 70% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alarm_topic.arn]
  ok_actions          = [aws_sns_topic.alarm_topic.arn]

  dimensions = {
    InstanceId = aws_instance.web.id
  }
}
