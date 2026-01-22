# AWS App + Oracle XE Database (Docker Compose)

Terraform templates to provision a Flask application connected to an Oracle XE 21c database running in Docker on AWS EC2.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                              AWS VPC                                │
│                           (10.0.0.0/16)                            │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                      Public Subnet                             │  │
│  │                       (10.0.1.0/24)                            │  │
│  │                                                                │  │
│  │  ┌─────────────────────┐      ┌─────────────────────────────┐ │  │
│  │  │   App Server        │      │      DB Server               │ │  │
│  │  │   (Ubuntu 24.04)    │      │      (Ubuntu 24.04)          │ │  │
│  │  │                     │      │                              │ │  │
│  │  │  ┌───────────────┐  │      │  ┌────────────────────────┐ │ │  │
│  │  │  │ Flask App     │──┼──────┼──│ Docker Compose         │ │ │  │
│  │  │  │ (Port 5000)   │  │      │  │                        │ │ │  │
│  │  │  └───────────────┘  │      │  │ ┌────────────────────┐ │ │ │  │
│  │  │                     │      │  │ │ Oracle XE 21c      │ │ │ │  │
│  │  │  • Python 3         │      │  │ │ (Port 1521)        │ │ │ │  │
│  │  │  • oracledb         │      │  │ │                    │ │ │ │  │
│  │  │  • Gunicorn         │      │  │ │ gvenzl/oracle-xe:  │ │ │ │  │
│  │  │                     │      │  │ │ 21-slim            │ │ │ │  │
│  │  │                     │      │  │ └────────────────────┘ │ │ │  │
│  │  │                     │      │  └────────────────────────┘ │ │  │
│  │  │                     │      │                              │ │  │
│  │  │                     │      │  • AWS CLI v2                │ │  │
│  │  │                     │      │  • Oracle Instant Client     │ │  │
│  │  │                     │      │  • impdp/expdp tools         │ │  │
│  │  └─────────────────────┘      └─────────────────────────────┘ │  │
│  │                                                                │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Features

### Database Server
- **Ubuntu 24.04 LTS** (or 22.04)
- **Docker & Docker Compose** - Container runtime
- **Oracle XE 21c** - Running in Docker container (`gvenzl/oracle-xe:21-slim`)
- **AWS CLI v2** - Pre-configured (if credentials provided)
- **Oracle Instant Client** - For Data Pump operations (impdp/expdp)
- **Auto-start** - Systemd service ensures Oracle XE starts on boot
- **Helper Scripts** - Ready-to-use scripts for common operations

### Application Server
- **Ubuntu 24.04 LTS** (or 22.04)
- **Flask Application** - Web UI displaying database content
- **python-oracledb** - Modern Oracle driver (thin mode, no client needed)
- **Gunicorn** - Production WSGI server
- **REST APIs** - JSON endpoints for users and orders

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **SSH Key Pair** created in AWS
3. **Terraform** >= 1.0.0 installed
4. **AWS CLI** configured locally (optional)

## Quick Start

### 1. Clone/Copy the Templates

```bash
cd services/aws-app-db-oracle
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Required Variables:**
- `key_name` - Your AWS SSH key pair name
- `db_password` - Oracle database password (min 8 chars, uppercase, lowercase, numbers)

### 3. Initialize and Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Wait for Setup

The database server takes **5-10 minutes** to fully initialize (Docker image pull + Oracle XE startup).

Check progress:
```bash
# SSH to DB server
ssh -i your-key.pem ubuntu@<db_public_ip>

# View user-data log
tail -f /var/log/user-data.log

# View Oracle XE logs
docker logs -f oracle-xe
```

### 5. Access the Application

Once deployment is complete:
- **Web UI**: `http://<app_public_ip>:5000`
- **API - Users**: `http://<app_public_ip>:5000/api/users`
- **API - Orders**: `http://<app_public_ip>:5000/api/orders`
- **Health Check**: `http://<app_public_ip>:5000/health`

## Database Operations

### Connect via SQLPlus

```bash
# SSH to DB server
ssh -i your-key.pem ubuntu@<db_public_ip>

# Connect to Oracle
docker exec -it oracle-xe bash -lc 'sqlplus appuser/Azalio123456@XEPDB1'
```

### Run SQL Script

```bash
cd ~/oracle_xe
./run-sql.sh your-script.sql
```

### Export Data (Data Pump)

```bash
cd ~/oracle_xe
./export-data.sh 19  # Export with version 19 compatibility
```

### Check Database Status

```bash
cd ~/oracle_xe
./check-status.sh
```

### View Docker Logs

```bash
docker logs -f oracle-xe
```

## Directory Structure

```
terraform-oracle-docker/
├── modules/
│   ├── ec2-app/         # Application server module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ec2-db/          # Database server module (Docker)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── iam/             # IAM roles and policies
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security/        # Security groups
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── vpc/             # VPC and networking
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── services/
    └── aws-app-db-oracle/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── terraform.tfvars.example
```

## Instance Requirements

### Database Server
| Resource | Minimum | Recommended |
|----------|---------|-------------|
| Instance Type | t3.medium | t3.large |
| vCPU | 2 | 2+ |
| Memory | 4 GB | 8 GB |
| Storage | 20 GB | 30 GB+ |

### Application Server
| Resource | Minimum | Recommended |
|----------|---------|-------------|
| Instance Type | t2.micro | t2.small |
| vCPU | 1 | 1 |
| Memory | 1 GB | 2 GB |
| Storage | 8 GB | 8 GB |

## Security Considerations

1. **SSH Access**: Restrict `ssh_allowed_cidr` to your IP in production
2. **Database Password**: Use a strong password meeting Oracle requirements
3. **AWS Credentials**: If providing AWS credentials for CLI, use IAM roles in production
4. **Security Groups**: Review and adjust security group rules as needed

## Troubleshooting

### Oracle XE Not Starting

```bash
# Check container status
docker ps -a

# Check logs
docker logs oracle-xe

# Restart container
cd ~/oracle_xe
docker compose down
docker compose up -d
```

### Application Can't Connect to Database

1. Wait 5-10 minutes for Oracle XE to fully initialize
2. Verify security group allows port 1521 between servers
3. Check Flask app logs:
   ```bash
   sudo journalctl -u flask-app -f
   ```

### Data Pump Export Fails

1. Ensure directory permissions are granted:
   ```bash
   docker exec -i oracle-xe sqlplus -s / as sysdba <<EOF
   ALTER SESSION SET CONTAINER = XEPDB1;
   GRANT READ, WRITE ON DIRECTORY DATA_PUMP_DIR TO appuser;
   EXIT;
   EOF
   ```

## Cost Estimation

Approximate monthly costs (ap-south-1 region):
- t3.medium DB server: ~$30/month
- t2.micro App server: ~$9/month (or free tier)
- EBS storage (30GB): ~$3/month
- **Total**: ~$42/month

## Clean Up

```bash
terraform destroy
```

## License

This project is provided as-is for educational and development purposes.

## References

- [gvenzl/oracle-xe Docker Image](https://github.com/gvenzl/oci-oracle-xe)
- [python-oracledb Documentation](https://python-oracledb.readthedocs.io/)
- [Oracle XE Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/21/xeinl/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

