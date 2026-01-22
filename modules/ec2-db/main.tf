################################################################################
# EC2 DB Module - Oracle XE 21c via Docker Compose on Ubuntu
# Uses gvenzl/oracle-xe:21-slim Docker image
# Includes AWS CLI, Oracle Instant Client for Data Pump operations
################################################################################

resource "aws_instance" "db" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.key_name
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -x

    echo "=== Starting Oracle XE 21c Database Server Setup (Docker Compose) ==="
    echo "Start time: $$(date)"

    #---------------------------------------------------------------------------
    # Update System
    #---------------------------------------------------------------------------
    apt-get update -y
    apt-get upgrade -y

    #---------------------------------------------------------------------------
    # Install Docker and Docker Compose
    #---------------------------------------------------------------------------
    echo "=== Installing Docker and Docker Compose ==="

    # Remove old Docker versions if any
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Install prerequisites
    apt-get install -y ca-certificates curl gnupg lsb-release

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up the repository
    echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    # Add ubuntu user to docker group
    usermod -aG docker ubuntu

    # Verify installation
    docker --version
    docker compose version

    #---------------------------------------------------------------------------
    # Install AWS CLI v2
    #---------------------------------------------------------------------------
    echo "=== Installing AWS CLI v2 ==="

    apt-get install -y unzip curl

    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -o awscliv2.zip
    ./aws/install --update
    rm -rf awscliv2.zip aws

    # Verify AWS CLI installation
    aws --version

    # Configure AWS credentials (if provided)
    %{ if var.aws_access_key_id != "" && var.aws_secret_access_key != "" }
    mkdir -p /home/ubuntu/.aws
    cat > /home/ubuntu/.aws/credentials <<AWSCREDS
[default]
aws_access_key_id = ${var.aws_access_key_id}
aws_secret_access_key = ${var.aws_secret_access_key}
AWSCREDS

    cat > /home/ubuntu/.aws/config <<AWSCONFIG
[default]
region = ${var.aws_region}
output = json
AWSCONFIG

    chown -R ubuntu:ubuntu /home/ubuntu/.aws
    chmod 600 /home/ubuntu/.aws/credentials
    %{ endif }

    #---------------------------------------------------------------------------
    # Install Oracle Instant Client (for impdp/expdp operations)
    #---------------------------------------------------------------------------
    echo "=== Installing Oracle Instant Client ==="

    apt-get install -y libaio1t64 || apt-get install -y libaio1

    # Create Oracle directory
    mkdir -p /home/ubuntu/oracle
    cd /home/ubuntu/oracle

    # Download Instant Client packages
    wget -q https://download.oracle.com/otn_software/linux/instantclient/219000/instantclient-basiclite-linux.x64-21.9.0.0.0dbru.zip
    wget -q https://download.oracle.com/otn_software/linux/instantclient/219000/instantclient-tools-linux.x64-21.9.0.0.0dbru.zip

    # Extract packages
    unzip -o instantclient-basiclite-linux.x64-21.9.0.0.0dbru.zip
    unzip -o instantclient-tools-linux.x64-21.9.0.0.0dbru.zip

    # Clean up zip files
    rm -f *.zip

    # Set ownership
    chown -R ubuntu:ubuntu /home/ubuntu/oracle

    # Configure environment variables
    cat >> /home/ubuntu/.bashrc <<ORAENV

# Oracle Instant Client Environment
export LD_LIBRARY_PATH=\$$HOME/oracle/instantclient_21_9:\$$LD_LIBRARY_PATH
export PATH=\$$HOME/oracle/instantclient_21_9:\$$PATH
ORAENV

    # Create symbolic link for libaio if needed
    if [ -f /lib/x86_64-linux-gnu/libaio.so.1t64 ]; then
      ln -sf /lib/x86_64-linux-gnu/libaio.so.1t64 /lib/x86_64-linux-gnu/libaio.so.1 2>/dev/null || true
    fi
    ldconfig

    #---------------------------------------------------------------------------
    # Create Docker Compose Configuration for Oracle XE
    #---------------------------------------------------------------------------
    echo "=== Creating Docker Compose Configuration ==="

    mkdir -p /home/ubuntu/oracle_xe
    cd /home/ubuntu/oracle_xe

    cat > /home/ubuntu/oracle_xe/docker-compose.yml <<DOCKERCOMPOSE
services:
  oracle:
    image: gvenzl/oracle-xe:21-slim
    container_name: oracle-xe
    environment:
      ORACLE_PASSWORD: "${var.db_password}"
      APP_USER: "${var.db_user}"
      APP_USER_PASSWORD: "${var.db_password}"
    ports:
      - "1521:1521"
    volumes:
      - oracle-data:/opt/oracle/oradata
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 120s

volumes:
  oracle-data:
DOCKERCOMPOSE

    chown -R ubuntu:ubuntu /home/ubuntu/oracle_xe

    #---------------------------------------------------------------------------
    # Create Seed SQL Script
    #---------------------------------------------------------------------------
    echo "=== Creating Seed SQL Script ==="

    cat > /home/ubuntu/oracle_xe/seed.sql <<SEEDSQL
-- Create USERS table
CREATE TABLE users (
  user_id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  name VARCHAR2(100) NOT NULL,
  email VARCHAR2(100) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create ORDERS table
CREATE TABLE orders (
  order_id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id NUMBER NOT NULL,
  product VARCHAR2(200) NOT NULL,
  amount NUMBER(10,2) NOT NULL,
  order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Create indexes
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_users_email ON users(email);

-- Seed sample data - USERS
INSERT INTO users (user_id, name, email) VALUES (1, 'Alice Johnson', 'alice@example.com');
INSERT INTO users (user_id, name, email) VALUES (2, 'Bob Smith', 'bob@example.com');
INSERT INTO users (user_id, name, email) VALUES (3, 'Carol Williams', 'carol@example.com');
INSERT INTO users (user_id, name, email) VALUES (4, 'David Brown', 'david@example.com');
INSERT INTO users (user_id, name, email) VALUES (5, 'Eva Martinez', 'eva@example.com');
INSERT INTO users (user_id, name, email) VALUES (6, 'Frank Lee', 'frank@example.com');
INSERT INTO users (user_id, name, email) VALUES (7, 'Grace Kim', 'grace@example.com');
INSERT INTO users (user_id, name, email) VALUES (8, 'Henry Wilson', 'henry@example.com');
INSERT INTO users (user_id, name, email) VALUES (9, 'Iris Chen', 'iris@example.com');
INSERT INTO users (user_id, name, email) VALUES (10, 'Jack Taylor', 'jack@example.com');

-- Seed sample data - ORDERS
INSERT INTO orders (order_id, user_id, product, amount) VALUES (1, 1, 'Laptop Pro 15', 1299.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (2, 1, 'Wireless Mouse', 49.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (3, 2, 'Mechanical Keyboard', 159.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (4, 2, 'Monitor 27 inch', 399.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (5, 3, 'USB-C Hub', 79.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (6, 3, 'Webcam HD', 129.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (7, 4, 'Headphones Wireless', 249.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (8, 5, 'SSD 1TB', 109.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (9, 5, 'RAM 32GB Kit', 149.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (10, 6, 'Graphics Card RTX', 599.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (11, 7, 'Power Supply 750W', 89.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (12, 7, 'PC Case ATX', 119.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (13, 8, 'CPU Cooler', 69.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (14, 9, 'Motherboard Gaming', 289.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (15, 10, 'NVMe SSD 2TB', 199.99);

COMMIT;

-- Verify data
SELECT 'Users count: ' || COUNT(*) AS user_count FROM users;
SELECT 'Orders count: ' || COUNT(*) AS order_count FROM orders;
SEEDSQL

    chown ubuntu:ubuntu /home/ubuntu/oracle_xe/seed.sql

    #---------------------------------------------------------------------------
    # Create Helper Scripts
    #---------------------------------------------------------------------------
    echo "=== Creating Helper Scripts ==="

    # Script to run SQL in Oracle XE container
    cat > /home/ubuntu/oracle_xe/run-sql.sh <<RUNSQL
#!/bin/bash
# Run SQL script in Oracle XE container
# Usage: ./run-sql.sh <sql_file>
docker exec -i oracle-xe bash -lc "sqlplus ${var.db_user}/${var.db_password}@XEPDB1" < "\$$1"
RUNSQL

    # Script to export data using Data Pump
    cat > /home/ubuntu/oracle_xe/export-data.sh <<EXPORTDATA
#!/bin/bash
# Export schema using Oracle Data Pump
# Usage: ./export-data.sh [version]
VERSION=\$${1:-19}

# Grant Data Pump directory permissions
docker exec -i oracle-xe sqlplus -s / as sysdba <<EOF
ALTER SESSION SET CONTAINER = XEPDB1;
GRANT READ, WRITE ON DIRECTORY DATA_PUMP_DIR TO ${var.db_user};
EXIT;
EOF

# Run export
docker exec -it oracle-xe expdp ${var.db_user}/${var.db_password}@XEPDB1 schemas=${var.db_user} directory=DATA_PUMP_DIR dumpfile=${var.db_user}_export.dmp logfile=${var.db_user}_export.log version=\$$VERSION

# Move files to accessible location
docker exec oracle-xe sh -c "mv /opt/oracle/admin/XE/dpdump/*/${var.db_user}_export.dmp /opt/oracle/admin/XE/dpdump/${var.db_user}_export.dmp 2>/dev/null || true"
docker exec oracle-xe sh -c "mv /opt/oracle/admin/XE/dpdump/*/${var.db_user}_export.log /opt/oracle/admin/XE/dpdump/${var.db_user}_export.log 2>/dev/null || true"

# Copy to host
docker cp oracle-xe:/opt/oracle/admin/XE/dpdump/${var.db_user}_export.dmp .
docker cp oracle-xe:/opt/oracle/admin/XE/dpdump/${var.db_user}_export.log .

echo "Export complete. Files: ${var.db_user}_export.dmp, ${var.db_user}_export.log"
EXPORTDATA

    # Script to check database status
    cat > /home/ubuntu/oracle_xe/check-status.sh <<CHECKSTATUS
#!/bin/bash
# Check Oracle XE database status
echo "=== Container Status ==="
docker ps -f name=oracle-xe

echo ""
echo "=== Database Connection Test ==="
docker exec -it oracle-xe bash -lc "sqlplus ${var.db_user}/${var.db_password}@XEPDB1 <<SQL
SELECT * FROM users;
exit
SQL"
CHECKSTATUS

    chmod +x /home/ubuntu/oracle_xe/*.sh
    chown -R ubuntu:ubuntu /home/ubuntu/oracle_xe

    #---------------------------------------------------------------------------
    # Start Oracle XE Container
    #---------------------------------------------------------------------------
    echo "=== Starting Oracle XE Container ==="

    cd /home/ubuntu/oracle_xe
    docker compose up -d

    # Wait for Oracle XE to be healthy (can take 2-5 minutes on first start)
    echo "Waiting for Oracle XE to start (this may take several minutes)..."
    
    MAX_WAIT=600
    WAIT_INTERVAL=15
    ELAPSED=0

    while [ $$ELAPSED -lt $$MAX_WAIT ]; do
      # Check if container is healthy
      HEALTH=$$(docker inspect --format='{{.State.Health.Status}}' oracle-xe 2>/dev/null || echo "starting")
      
      if [ "$$HEALTH" = "healthy" ]; then
        echo "Oracle XE is healthy and ready!"
        break
      fi

      # Alternative: Try to connect
      docker exec oracle-xe bash -lc "echo 'SELECT 1 FROM DUAL;' | sqlplus -s ${var.db_user}/${var.db_password}@XEPDB1" 2>/dev/null && {
        echo "Oracle XE is ready!"
        break
      }

      echo "Still waiting... ($$ELAPSED seconds elapsed, status: $$HEALTH)"
      sleep $$WAIT_INTERVAL
      ELAPSED=$$((ELAPSED + WAIT_INTERVAL))
    done

    if [ $$ELAPSED -ge $$MAX_WAIT ]; then
      echo "WARNING: Timeout waiting for Oracle XE. Check logs with: docker logs oracle-xe"
    fi

    #---------------------------------------------------------------------------
    # Run Seed Script
    #---------------------------------------------------------------------------
    echo "=== Running Seed Script ==="

    # Give a bit more time for the database to be fully ready
    sleep 30

    cd /home/ubuntu/oracle_xe
    docker exec -i oracle-xe bash -lc "sqlplus ${var.db_user}/${var.db_password}@XEPDB1" < seed.sql || {
      echo "Seed script failed. Retrying in 30 seconds..."
      sleep 30
      docker exec -i oracle-xe bash -lc "sqlplus ${var.db_user}/${var.db_password}@XEPDB1" < seed.sql
    }

    #---------------------------------------------------------------------------
    # Grant Data Pump Directory Permissions
    #---------------------------------------------------------------------------
    echo "=== Granting Data Pump Permissions ==="

    docker exec -i oracle-xe sqlplus -s / as sysdba <<SQLCMD
ALTER SESSION SET CONTAINER = XEPDB1;
GRANT READ, WRITE ON DIRECTORY DATA_PUMP_DIR TO ${var.db_user};
EXIT;
SQLCMD

    #---------------------------------------------------------------------------
    # Create Systemd Service for Auto-Start
    #---------------------------------------------------------------------------
    echo "=== Creating Systemd Service ==="

    cat > /etc/systemd/system/oracle-xe-docker.service <<SYSTEMD
[Unit]
Description=Oracle XE Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/oracle_xe
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=root

[Install]
WantedBy=multi-user.target
SYSTEMD

    systemctl daemon-reload
    systemctl enable oracle-xe-docker

    #---------------------------------------------------------------------------
    # Final Verification
    #---------------------------------------------------------------------------
    echo "=== Final Verification ==="

    echo "Docker containers:"
    docker ps

    echo ""
    echo "Testing database connection:"
    docker exec -it oracle-xe bash -lc "sqlplus ${var.db_user}/${var.db_password}@XEPDB1 <<SQL
SELECT COUNT(*) AS user_count FROM users;
SELECT COUNT(*) AS order_count FROM orders;
exit
SQL"

    echo "=== Oracle XE 21c Database Server Setup Complete ==="
    echo "End time: $$(date)"
    echo ""
    echo "Connection Info:"
    echo "  Host: $$(hostname -I | awk '{print $$1}')"
    echo "  Port: 1521"
    echo "  Service: XEPDB1"
    echo "  User: ${var.db_user}"
    echo ""
    echo "Connect string: ${var.db_user}/${var.db_password}@$$(hostname -I | awk '{print $$1}'):1521/XEPDB1"
    echo ""
    echo "Useful commands:"
    echo "  - Check status: cd ~/oracle_xe && ./check-status.sh"
    echo "  - Run SQL: cd ~/oracle_xe && ./run-sql.sh <file.sql>"
    echo "  - Export data: cd ~/oracle_xe && ./export-data.sh [version]"
    echo "  - View logs: docker logs -f oracle-xe"
  EOF

  tags = merge(var.tags, {
    Name     = "${var.environment}-oracle-db-server"
    Role     = "Database"
    Database = "Oracle XE 21c (Docker)"
  })

  lifecycle {
    create_before_destroy = true
  }
}
