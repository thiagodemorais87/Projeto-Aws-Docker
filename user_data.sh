   ```bash
    #!/bin/bash
    
    yum update -y
    yum install docker -y
    
    systemctl start docker
    systemctl enable docker
    
    usermod -a -G docker ec2-user
   
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    
    case $AZ in
      "us-east-1a") EFS_IP="10.0.2.18" ;;
      "us-east-1b") EFS_IP="10.0.4.36" ;;
      *) echo "AZ não reconhecida"; exit 1 ;;
    esac
    
    mkdir -p /mnt/efs
    mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 $EFS_IP:/ /mnt/efs
    mkdir -p /mnt/efs/wordpress_data
    
    cat <<EOL > /home/ec2-user/docker-compose.yml
    services:
      wordpress:
        image: wordpress:latest
        ports:
          - "80:80"
        environment:
          WORDPRESS_DB_HOST: <rds-endpoint>  # Ex: db-1.cro2a3b45678.region.amazonaws.com
          WORDPRESS_DB_USER: <user>          # Ex: admin
          WORDPRESS_DB_PASSWORD: <password>  # Ex: senha123
          WORDPRESS_DB_NAME: wordpress
        volumes:
          - wordpress_data:/var/www/html
    
    volumes:
      wordpress_data:
        driver_opts:
          type: "nfs"
          o: "addr=$EFS_IP,nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2"
          device: ":/"
    
    EOL
    
    chown ec2-user:ec2-user /home/ec2-user/docker-compose.yml
    chown ec2-user:ec2-user /mnt/efs/wordpress_data
 
    sudo -u ec2-user /usr/local/bin/docker-compose -f /home/ec2-user/docker-compose.yml up -d
    ```
