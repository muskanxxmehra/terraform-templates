#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -x

echo "=== DAY 0 - Oracle XE 21c Database Server Setup ==="
echo "Start time: $(date)"

#---------------------------------------------------------------------------
# STEP 1 - Installation of Docker Compose
#---------------------------------------------------------------------------
echo "=== STEP 1 - Installing Docker Compose ==="

sudo apt-get remove docker docker-engine docker.io containerd runc -y
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

docker --version
docker compose version

sudo usermod -aG docker ubuntu

#---------------------------------------------------------------------------
# STEP 2 - Install AWS and configure AWS
#---------------------------------------------------------------------------
echo "=== STEP 2 - Installing and Configuring AWS CLI ==="

sudo apt update
sudo apt install -y unzip curl

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws

aws --version

%{ if aws_access_key_id != "" && aws_secret_access_key != "" }
# Configure AWS credentials for ubuntu user
sudo -u ubuntu aws configure set aws_access_key_id ${aws_access_key_id}
sudo -u ubuntu aws configure set aws_secret_access_key ${aws_secret_access_key}
sudo -u ubuntu aws configure set region ${aws_region}
sudo -u ubuntu aws configure set output json

# Also configure for root
aws configure set aws_access_key_id ${aws_access_key_id}
aws configure set aws_secret_access_key ${aws_secret_access_key}
aws configure set region ${aws_region}
aws configure set output json
%{ endif }

#---------------------------------------------------------------------------
# STEP 3 - Install Oracle Instant Client (includes impdp)
#---------------------------------------------------------------------------
echo "=== STEP 3 - Installing Oracle Instant Client ==="

sudo apt update
sudo apt install -y unzip libaio1t64 || sudo apt install -y unzip libaio1

mkdir -p /home/ubuntu/oracle
cd /home/ubuntu/oracle

wget https://download.oracle.com/otn_software/linux/instantclient/219000/instantclient-basiclite-linux.x64-21.9.0.0.0dbru.zip
wget https://download.oracle.com/otn_software/linux/instantclient/219000/instantclient-tools-linux.x64-21.9.0.0.0dbru.zip

unzip -o instantclient-basiclite-*.zip
unzip -o instantclient-tools-*.zip
rm -f *.zip

chown -R ubuntu:ubuntu /home/ubuntu/oracle

# Configure environment for ubuntu user
echo 'export LD_LIBRARY_PATH=$HOME/oracle/instantclient_21_9' >> /home/ubuntu/.bashrc
echo 'export PATH=$HOME/oracle/instantclient_21_9:$PATH' >> /home/ubuntu/.bashrc

sudo ln -sf /lib/x86_64-linux-gnu/libaio.so.1t64 /lib/x86_64-linux-gnu/libaio.so.1 2>/dev/null || true
sudo ldconfig

#---------------------------------------------------------------------------
# STEP 7 - Creation of docker compose file
#---------------------------------------------------------------------------
echo "=== STEP 7 - Creating Docker Compose Configuration ==="

mkdir -p /home/ubuntu/oracle_xe
cd /home/ubuntu/oracle_xe

cat > /home/ubuntu/oracle_xe/docker-compose.yml << 'COMPOSEEOF'
services:
  oracle:
    image: gvenzl/oracle-xe:21-slim
    container_name: oracle-xe
    environment:
      ORACLE_PASSWORD: "${db_password}"
      APP_USER: "${db_user}"
      APP_USER_PASSWORD: "${db_password}"
    ports:
      - "1521:1521"
    volumes:
      - oracle-data:/opt/oracle/oradata
volumes:
  oracle-data:
COMPOSEEOF

chown -R ubuntu:ubuntu /home/ubuntu/oracle_xe

#---------------------------------------------------------------------------
# STEP 8 - Start Oracle XE Container
#---------------------------------------------------------------------------
echo "=== STEP 8 - Starting Oracle XE Container ==="

cd /home/ubuntu/oracle_xe
docker compose up -d

echo "Waiting for Oracle XE to start (this may take 2-3 minutes)..."
sleep 180

# Check container status
docker ps
docker logs oracle-xe | tail -20

#---------------------------------------------------------------------------
# STEP 9 - Create and Run seed.sql (50 Countries + 50 Customers)
#---------------------------------------------------------------------------
echo "=== STEP 9 - Creating and Running Seed SQL ==="

cat > /home/ubuntu/oracle_xe/seed.sql << 'SQLEOF'
-- ============================
-- DROP TABLES (SAFE)
-- ============================
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE customers CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE country CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- ============================
-- COUNTRY TABLE
-- ============================
CREATE TABLE country (
    country_name VARCHAR2(50) PRIMARY KEY
);

-- ============================
-- CUSTOMERS TABLE
-- ============================
CREATE TABLE customers (
    customer_id   NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    customer_name VARCHAR2(100) NOT NULL,
    email         VARCHAR2(100) NOT NULL,
    country_name  VARCHAR2(50) NOT NULL,
    created_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_country_name
        FOREIGN KEY (country_name)
        REFERENCES country(country_name)
);

-- ============================
-- INSERT 50 COUNTRIES
-- ============================
INSERT INTO country VALUES ('India');
INSERT INTO country VALUES ('United States');
INSERT INTO country VALUES ('United Kingdom');
INSERT INTO country VALUES ('Canada');
INSERT INTO country VALUES ('Australia');
INSERT INTO country VALUES ('Germany');
INSERT INTO country VALUES ('France');
INSERT INTO country VALUES ('Japan');
INSERT INTO country VALUES ('Singapore');
INSERT INTO country VALUES ('Brazil');
INSERT INTO country VALUES ('Mexico');
INSERT INTO country VALUES ('Italy');
INSERT INTO country VALUES ('Spain');
INSERT INTO country VALUES ('Netherlands');
INSERT INTO country VALUES ('Sweden');
INSERT INTO country VALUES ('Norway');
INSERT INTO country VALUES ('Denmark');
INSERT INTO country VALUES ('Finland');
INSERT INTO country VALUES ('Switzerland');
INSERT INTO country VALUES ('Austria');
INSERT INTO country VALUES ('Belgium');
INSERT INTO country VALUES ('Portugal');
INSERT INTO country VALUES ('Ireland');
INSERT INTO country VALUES ('Poland');
INSERT INTO country VALUES ('Czech Republic');
INSERT INTO country VALUES ('South Korea');
INSERT INTO country VALUES ('China');
INSERT INTO country VALUES ('Taiwan');
INSERT INTO country VALUES ('Hong Kong');
INSERT INTO country VALUES ('Thailand');
INSERT INTO country VALUES ('Vietnam');
INSERT INTO country VALUES ('Malaysia');
INSERT INTO country VALUES ('Indonesia');
INSERT INTO country VALUES ('Philippines');
INSERT INTO country VALUES ('New Zealand');
INSERT INTO country VALUES ('South Africa');
INSERT INTO country VALUES ('Nigeria');
INSERT INTO country VALUES ('Egypt');
INSERT INTO country VALUES ('Kenya');
INSERT INTO country VALUES ('Morocco');
INSERT INTO country VALUES ('Argentina');
INSERT INTO country VALUES ('Chile');
INSERT INTO country VALUES ('Colombia');
INSERT INTO country VALUES ('Peru');
INSERT INTO country VALUES ('Venezuela');
INSERT INTO country VALUES ('United Arab Emirates');
INSERT INTO country VALUES ('Saudi Arabia');
INSERT INTO country VALUES ('Israel');
INSERT INTO country VALUES ('Turkey');
INSERT INTO country VALUES ('Russia');

-- ============================
-- INSERT 50 CUSTOMERS
-- ============================
-- India (5)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Amit Sharma', 'amit.sharma@gmail.com', 'India');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Neha Verma', 'neha.verma@gmail.com', 'India');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Rajesh Kumar', 'rajesh.kumar@gmail.com', 'India');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Priya Patel', 'priya.patel@gmail.com', 'India');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Vikram Singh', 'vikram.singh@gmail.com', 'India');

-- United States (5)
INSERT INTO customers (customer_name, email, country_name) VALUES ('John Doe', 'john.doe@gmail.com', 'United States');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Jane Smith', 'jane.smith@gmail.com', 'United States');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Michael Johnson', 'michael.johnson@gmail.com', 'United States');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Emily Davis', 'emily.davis@gmail.com', 'United States');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Robert Wilson', 'robert.wilson@gmail.com', 'United States');

-- United Kingdom (3)
INSERT INTO customers (customer_name, email, country_name) VALUES ('David Brown', 'david.brown@gmail.com', 'United Kingdom');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Emma Wilson', 'emma.wilson@gmail.com', 'United Kingdom');
INSERT INTO customers (customer_name, email, country_name) VALUES ('James Taylor', 'james.taylor@gmail.com', 'United Kingdom');

-- Canada (3)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Liam Martin', 'liam.martin@gmail.com', 'Canada');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Olivia Taylor', 'olivia.taylor@gmail.com', 'Canada');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Ethan Campbell', 'ethan.campbell@gmail.com', 'Canada');

-- Australia (3)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Noah Anderson', 'noah.anderson@gmail.com', 'Australia');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Sophia Thomas', 'sophia.thomas@gmail.com', 'Australia');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Charlotte White', 'charlotte.white@gmail.com', 'Australia');

-- Germany (3)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Hans Mueller', 'hans.mueller@gmail.com', 'Germany');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Anna Schmidt', 'anna.schmidt@gmail.com', 'Germany');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Felix Weber', 'felix.weber@gmail.com', 'Germany');

-- France (3)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Pierre Dubois', 'pierre.dubois@gmail.com', 'France');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Marie Laurent', 'marie.laurent@gmail.com', 'France');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Jean Moreau', 'jean.moreau@gmail.com', 'France');

-- Japan (3)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Kenji Tanaka', 'kenji.tanaka@gmail.com', 'Japan');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Yuki Sato', 'yuki.sato@gmail.com', 'Japan');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Haruki Yamamoto', 'haruki.yamamoto@gmail.com', 'Japan');

-- Singapore (2)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Wei Ling', 'wei.ling@gmail.com', 'Singapore');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Chen Hao', 'chen.hao@gmail.com', 'Singapore');

-- Brazil (2)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Carlos Silva', 'carlos.silva@gmail.com', 'Brazil');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Ana Costa', 'ana.costa@gmail.com', 'Brazil');

-- Mexico (2)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Miguel Rodriguez', 'miguel.rodriguez@gmail.com', 'Mexico');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Isabella Hernandez', 'isabella.hernandez@gmail.com', 'Mexico');

-- Italy (2)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Marco Rossi', 'marco.rossi@gmail.com', 'Italy');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Giulia Bianchi', 'giulia.bianchi@gmail.com', 'Italy');

-- Spain (2)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Pablo Garcia', 'pablo.garcia@gmail.com', 'Spain');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Sofia Martinez', 'sofia.martinez@gmail.com', 'Spain');

-- Netherlands (2)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Jan de Vries', 'jan.devries@gmail.com', 'Netherlands');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Emma Bakker', 'emma.bakker@gmail.com', 'Netherlands');

-- South Korea (2)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Min-jun Kim', 'minjun.kim@gmail.com', 'South Korea');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Ji-young Park', 'jiyoung.park@gmail.com', 'South Korea');

-- China (2)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Li Wei', 'li.wei@gmail.com', 'China');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Zhang Yan', 'zhang.yan@gmail.com', 'China');

-- South Africa (2)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Thabo Molefe', 'thabo.molefe@gmail.com', 'South Africa');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Naledi Dlamini', 'naledi.dlamini@gmail.com', 'South Africa');

-- United Arab Emirates (2)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Ahmed Al-Maktoum', 'ahmed.almaktoum@gmail.com', 'United Arab Emirates');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Fatima Hassan', 'fatima.hassan@gmail.com', 'United Arab Emirates');

-- Argentina (2)
INSERT INTO customers (customer_name, email, country_name) VALUES ('Diego Fernandez', 'diego.fernandez@gmail.com', 'Argentina');
INSERT INTO customers (customer_name, email, country_name) VALUES ('Valentina Lopez', 'valentina.lopez@gmail.com', 'Argentina');

COMMIT;

-- ============================
-- VERIFY DATA
-- ============================
SELECT 'Countries: ' || COUNT(*) AS count_info FROM country;
SELECT 'Customers: ' || COUNT(*) AS count_info FROM customers;
SQLEOF

chown ubuntu:ubuntu /home/ubuntu/oracle_xe/seed.sql

# Wait a bit more and run seed script
sleep 30

docker exec -i oracle-xe bash -lc "sqlplus ${db_user}/${db_password}@XEPDB1" < /home/ubuntu/oracle_xe/seed.sql || {
  echo "First attempt failed, retrying in 60 seconds..."
  sleep 60
  docker exec -i oracle-xe bash -lc "sqlplus ${db_user}/${db_password}@XEPDB1" < /home/ubuntu/oracle_xe/seed.sql
}

# Verify data
echo "=== Verifying Data ==="
docker exec -it oracle-xe bash -lc "sqlplus ${db_user}/${db_password}@XEPDB1 <<SQL
SELECT 'Total Countries: ' || COUNT(*) FROM country;
SELECT 'Total Customers: ' || COUNT(*) FROM customers;
SELECT country_name, COUNT(*) as customer_count FROM customers GROUP BY country_name ORDER BY customer_count DESC;
EXIT;
SQL"

#---------------------------------------------------------------------------
# Create Systemd Service for Auto-Start
#---------------------------------------------------------------------------
echo "=== Creating Systemd Service ==="

cat > /etc/systemd/system/oracle-xe-docker.service << 'SYSTEMDEOF'
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
SYSTEMDEOF

systemctl daemon-reload
systemctl enable oracle-xe-docker

#---------------------------------------------------------------------------
# Final Output
#---------------------------------------------------------------------------
echo "=== DAY 0 Setup Complete ==="
echo "End time: $(date)"
echo ""
echo "Connection Info:"
echo "  Host: $(hostname -I | awk '{print $1}')"
echo "  Port: 1521"
echo "  Service: XEPDB1"
echo "  User: ${db_user}"
echo ""
echo "Database contains:"
echo "  - 50 Countries in 'country' table"
echo "  - 50 Customers in 'customers' table"
echo ""
echo "Useful Commands:"
echo "  docker logs -f oracle-xe"
echo "  docker exec -it oracle-xe bash -lc 'sqlplus ${db_user}/${db_password}@XEPDB1'"
