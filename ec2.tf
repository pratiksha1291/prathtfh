provider "aws" {
    region ="ap-south-1"
    profile = "lwprofile"
  
}

resource "aws_security_group" "sgfromterra" {
  name        = "sgfromterra"
  description = "Allow TLS inbound traffic"
  

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "TLS from VPC"
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

  tags = {
    Name = "sgfromterra"
  }
}
resource "aws_instance" "myosfromterra" {
    ami = "ami-0447a12f28fddb066"
    instance_type = "t2.micro"
    key_name = "my_key"
    security_groups = [ "sgfromterra"  ]
    connection {
        type = "ssh"
        user = "ec2-user"
        private_key = file("C:/Users/Prat/Downloads/my_key.pem")
        host = aws_instance.myosfromterra.public_ip
    }
    provisioner "remote-exec" {
        inline = [
            "sudo yum install httpd  php git -y",
            "sudo systemctl restart httpd",
            "sudo systemctl enable httpd",
        ]
    }

    tags = {
        Name = "OsfromTerra"
    }
}

resource "aws_ebs_volume" "Mypendrive" {
  availability_zone = aws_instance.myosfromterra.availability_zone
  size = 1
  tags = {
    Name = "Mypendrive"
  }
}

resource "aws_volume_attachment" "AttachPendrive" {
   device_name = "/dev/sdh"
   volume_id   =  aws_ebs_volume.Mypendrive.id
   instance_id =  aws_instance.myosfromterra.id
   depends_on = [
       aws_ebs_volume.Mypendrive,
       aws_instance.myosfromterra
   ]
 }

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.AttachPendrive,
]

connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("C:/Users/Prat/Downloads/my_key.pem")
    host = aws_instance.myosfromterra.public_ip
}
provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/pratiksha1291/prathtfh.git /var/www/html/"
    ]
  }
}

resource "aws_s3_bucket" "MyTerraformBucket" {
  bucket = "mybucket1291"
  acl    = "public-read"
}
resource "aws_s3_bucket_object" "object1" {
  bucket = "mybucket1291"
  key    = "IMG_20181218_203816_024.jpg"
  source = "C:/Users/Prat/Pictures"
  acl = "public-read"
  content_type = "image/jpg"
  depends_on = [
      aws_s3_bucket.MyTerraformBucket
  ]
}

resource "aws_cloudfront_distribution" "myCloudfront1" {
    origin {
        domain_name = "mybucket1291.s3.amazonaws.com"
        origin_id   = "S3-mybucket1291" 
       


        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
    }
       
    enabled = true

    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-mybucket1291"

        forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }
    depends_on = [
        aws_s3_bucket_object.object1
    ]
}
