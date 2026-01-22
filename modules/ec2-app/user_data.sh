#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -x

echo "=== Starting App Server Setup ==="

apt-get update -y
apt-get upgrade -y

# Install Python
apt-get install -y python3 python3-pip python3-venv python3-dev gcc wget unzip
apt-get install -y libaio1t64 || apt-get install -y libaio1

# Install Python packages - force reinstall conflicting system packages first
pip3 install --break-system-packages --ignore-installed typing_extensions blinker werkzeug itsdangerous
pip3 install --break-system-packages oracledb flask gunicorn

# Verify installation
which gunicorn
gunicorn --version

# Create Flask Application
mkdir -p /opt/flask-app

cat > /opt/flask-app/app.py << 'APPEOF'
#!/usr/bin/env python3
from flask import Flask, jsonify, render_template_string
import oracledb
import os

app = Flask(__name__)

DB_CONFIG = {
    'host': os.environ.get('DB_HOST', 'localhost'),
    'port': int(os.environ.get('DB_PORT', '1521')),
    'service_name': os.environ.get('DB_SERVICE', 'XEPDB1'),
    'user': os.environ.get('DB_USER', 'appuser'),
    'password': os.environ.get('DB_PASSWORD', 'password')
}

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Flask App - Oracle XE</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 900px; margin: 0 auto; }
        h1 { color: #333; border-bottom: 2px solid #c74634; padding-bottom: 10px; }
        .success { background: #d4edda; color: #155724; padding: 15px; border-radius: 5px; }
        .error { background: #f8d7da; color: #721c24; padding: 15px; border-radius: 5px; }
        table { width: 100%%; border-collapse: collapse; margin: 20px 0; background: white; }
        th, td { padding: 12px; text-align: left; border: 1px solid #ddd; }
        th { background: #c74634; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Flask App with Oracle XE (Docker)</h1>
        <p><strong>Database:</strong> {{ db_host }}:1521/{{ db_service }}</p>
        {% if error %}
        <div class="error">Error: {{ error }}</div>
        {% else %}
        <div class="success">Connected to Oracle XE successfully!</div>
        {% endif %}
        <h2>Customers ({{ customers|length }})</h2>
        <table>
            <tr><th>ID</th><th>Name</th><th>Created At</th></tr>
            {% for customer in customers %}
            <tr><td>{{ customer[0] }}</td><td>{{ customer[1] }}</td><td>{{ customer[2] }}</td></tr>
            {% endfor %}
        </table>
    </div>
</body>
</html>
"""

def get_db_connection():
    dsn = f"{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['service_name']}"
    return oracledb.connect(user=DB_CONFIG['user'], password=DB_CONFIG['password'], dsn=dsn)

@app.route('/')
def index():
    customers, error = [], None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM customers ORDER BY id")
        customers = cursor.fetchall()
        cursor.close()
        conn.close()
    except Exception as e:
        error = str(e)
    return render_template_string(HTML_TEMPLATE, customers=customers, error=error, db_host=DB_CONFIG['host'], db_service=DB_CONFIG['service_name'])

@app.route('/health')
def health():
    try:
        conn = get_db_connection()
        conn.close()
        return jsonify({'status': 'healthy'})
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500

@app.route('/api/customers')
def api_customers():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id, name, created_at FROM customers")
        customers = [{'id': r[0], 'name': r[1], 'created_at': str(r[2])} for r in cursor.fetchall()]
        cursor.close()
        conn.close()
        return jsonify(customers)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
APPEOF

# Create Systemd Service - hardcode gunicorn path
cat > /etc/systemd/system/flask-app.service << SYSTEMDEOF
[Unit]
Description=Flask Application
After=network.target

[Service]
User=root
WorkingDirectory=/opt/flask-app
Environment="DB_HOST=${db_host}"
Environment="DB_PORT=1521"
Environment="DB_SERVICE=XEPDB1"
Environment="DB_USER=${db_user}"
Environment="DB_PASSWORD=${db_password}"
ExecStart=/usr/local/bin/gunicorn -w 2 -b 0.0.0.0:${app_port} app:app
Restart=always

[Install]
WantedBy=multi-user.target
SYSTEMDEOF

systemctl daemon-reload
systemctl enable flask-app

echo "Waiting 60 seconds for database..."
sleep 60

systemctl start flask-app

echo "=== App Server Setup Complete ==="
```

## Key Changes

1. **Removed all bash variable substitution** - Hardcoded `/usr/local/bin/gunicorn` instead of using dynamic path lookup
2. **Removed Jinja2 escaping** - Since the HTML template is inside a `'APPEOF'` heredoc (single quotes), Terraform won't try to interpolate those `{% %}` tags

## Database Connectivity Issue

You also have a network problem:
```
nc: connect to 10.0.1.28 port 1521 (tcp) failed: No route to host
