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
    <title>Customer Management System - Demo</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            min-height: 100vh;
            padding: 30px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        
        /* Header Section */
        .header {
            background: white;
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 25px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            text-align: center;
        }
        .header h1 { 
            color: #2d3748; 
            font-size: 2.2em;
            margin-bottom: 10px;
        }
        .header .subtitle {
            color: #718096;
            font-size: 1.1em;
            margin-bottom: 20px;
        }
        .demo-badge {
            display: inline-block;
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            color: white;
            padding: 8px 20px;
            border-radius: 20px;
            font-size: 0.9em;
            font-weight: 600;
        }
        
        /* Stats Cards */
        .stats-row {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 25px;
        }
        .stat-card {
            background: white;
            border-radius: 12px;
            padding: 25px;
            text-align: center;
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
        }
        .stat-card .number {
            font-size: 2.5em;
            font-weight: 700;
            color: #667eea;
        }
        .stat-card .label {
            color: #718096;
            font-size: 0.95em;
            margin-top: 5px;
        }
        .stat-card.success { border-top: 4px solid #48bb78; }
        .stat-card.info { border-top: 4px solid #4299e1; }
        .stat-card.warning { border-top: 4px solid #ed8936; }
        .stat-card.purple { border-top: 4px solid #9f7aea; }
        
        /* Connection Info */
        .connection-info {
            background: white;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 25px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
        }
        .connection-info h3 {
            color: #2d3748;
            margin-bottom: 15px;
            font-size: 1.1em;
        }
        .conn-details {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
        }
        .conn-item {
            background: #f7fafc;
            padding: 10px 15px;
            border-radius: 8px;
            font-size: 0.9em;
        }
        .conn-item strong { color: #4a5568; }
        .conn-item span { color: #667eea; font-family: monospace; }
        .status-badge {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 15px;
            font-size: 0.85em;
            font-weight: 600;
        }
        .status-badge.connected { background: #c6f6d5; color: #276749; }
        .status-badge.error { background: #fed7d7; color: #c53030; }
        
        /* Tables Section */
        .tables-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 25px;
            margin-bottom: 25px;
        }
        @media (max-width: 900px) {
            .tables-grid { grid-template-columns: 1fr; }
        }
        .table-card {
            background: white;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
        }
        .table-card h2 {
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            color: white;
            padding: 18px 25px;
            font-size: 1.2em;
        }
        table { width: 100%%; border-collapse: collapse; }
        th, td { padding: 14px 20px; text-align: left; border-bottom: 1px solid #e2e8f0; }
        th { background: #f7fafc; color: #4a5568; font-weight: 600; font-size: 0.9em; text-transform: uppercase; }
        tr:hover { background: #f7fafc; }
        td { color: #2d3748; }
        .email { color: #667eea; font-size: 0.9em; }
        .country-tag {
            display: inline-block;
            background: #e9d8fd;
            color: #6b46c1;
            padding: 4px 10px;
            border-radius: 12px;
            font-size: 0.85em;
        }
        
        /* Full Width Customer Table */
        .full-table {
            background: white;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
            margin-bottom: 25px;
        }
        .full-table h2 {
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            color: white;
            padding: 18px 25px;
            font-size: 1.2em;
        }
        .table-scroll { max-height: 400px; overflow-y: auto; }
        
        /* Footer */
        .footer {
            text-align: center;
            color: rgba(255,255,255,0.8);
            font-size: 0.9em;
            padding: 20px;
        }
        .footer a { color: white; }
        
        /* Error Message */
        .error-box {
            background: #fff5f5;
            border: 1px solid #fc8181;
            color: #c53030;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 25px;
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header">
            <h1>Customer Management System</h1>
            <p class="subtitle">Demo Application - Customer to Country Mapping</p>
            <span class="demo-badge">Oracle XE 21c + Flask + Python</span>
        </div>
        
        {% if error %}
        <div class="error-box">
            <strong>Database Connection Error:</strong> {{ error }}
        </div>
        {% endif %}
        
        <!-- Stats Cards -->
        <div class="stats-row">
            <div class="stat-card success">
                <div class="number">{{ total_customers }}</div>
                <div class="label">Total Customers</div>
            </div>
            <div class="stat-card info">
                <div class="number">{{ total_countries }}</div>
                <div class="label">Countries</div>
            </div>
            <div class="stat-card warning">
                <div class="number">{{ countries_with_customers }}</div>
                <div class="label">Active Regions</div>
            </div>
            <div class="stat-card purple">
                <div class="number">{{ top_country_count }}</div>
                <div class="label">Max per Country</div>
            </div>
        </div>
        
        <!-- Connection Info -->
        <div class="connection-info">
            <h3>Database Connection</h3>
            <div class="conn-details">
                <div class="conn-item"><strong>Host:</strong> <span>{{ db_host }}</span></div>
                <div class="conn-item"><strong>Port:</strong> <span>1521</span></div>
                <div class="conn-item"><strong>Service:</strong> <span>{{ db_service }}</span></div>
                <div class="conn-item"><strong>User:</strong> <span>{{ db_user }}</span></div>
                <div class="conn-item">
                    <strong>Status:</strong> 
                    {% if error %}
                    <span class="status-badge error">Disconnected</span>
                    {% else %}
                    <span class="status-badge connected">Connected</span>
                    {% endif %}
                </div>
            </div>
        </div>
        
        <!-- Two Column Tables -->
        <div class="tables-grid">
            <!-- Countries Table -->
            <div class="table-card">
                <h2>Countries ({{ total_countries }})</h2>
                <div class="table-scroll">
                    <table>
                        <thead>
                            <tr><th>Country Name</th><th>Customers</th></tr>
                        </thead>
                        <tbody>
                            {% for country in country_stats %}
                            <tr>
                                <td>{{ country[0] }}</td>
                                <td><strong>{{ country[1] }}</strong></td>
                            </tr>
                            {% endfor %}
                        </tbody>
                    </table>
                </div>
            </div>
            
            <!-- Top Countries -->
            <div class="table-card">
                <h2>Top Regions by Customers</h2>
                <div class="table-scroll">
                    <table>
                        <thead>
                            <tr><th>Rank</th><th>Country</th><th>Count</th></tr>
                        </thead>
                        <tbody>
                            {% for i, country in enumerate(top_countries) %}
                            <tr>
                                <td><strong>#{{ i + 1 }}</strong></td>
                                <td>{{ country[0] }}</td>
                                <td><strong>{{ country[1] }}</strong></td>
                            </tr>
                            {% endfor %}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
        
        <!-- Full Customer Table -->
        <div class="full-table">
            <h2>Customer Directory ({{ total_customers }} Records)</h2>
            <div class="table-scroll">
                <table>
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Customer Name</th>
                            <th>Email</th>
                            <th>Country</th>
                            <th>Created At</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for customer in customers %}
                        <tr>
                            <td>{{ customer[0] }}</td>
                            <td><strong>{{ customer[1] }}</strong></td>
                            <td class="email">{{ customer[2] }}</td>
                            <td><span class="country-tag">{{ customer[3] }}</span></td>
                            <td>{{ customer[4] }}</td>
                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
        </div>
        
        <!-- Footer -->
        <div class="footer">
            <p>Demo Application | Oracle XE 21c Database | Flask Framework</p>
        </div>
    </div>
</body>
</html>
"""

def get_db_connection():
    dsn = f"{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['service_name']}"
    return oracledb.connect(user=DB_CONFIG['user'], password=DB_CONFIG['password'], dsn=dsn)

@app.route('/')
def index():
    customers = []
    country_stats = []
    top_countries = []
    total_customers = 0
    total_countries = 0
    countries_with_customers = 0
    top_country_count = 0
    error = None
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get all customers with country mapping
        cursor.execute("""
            SELECT customer_id, customer_name, email, country_name, 
                   TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') 
            FROM customers 
            ORDER BY customer_id
        """)
        customers = cursor.fetchall()
        total_customers = len(customers)
        
        # Get country statistics
        cursor.execute("""
            SELECT c.country_name, COUNT(cu.customer_name) as customer_count
            FROM country c
            LEFT JOIN customers cu ON c.country_name = cu.country_name
            GROUP BY c.country_name
            ORDER BY c.country_name
        """)
        country_stats = cursor.fetchall()
        total_countries = len(country_stats)
        
        # Get top countries by customer count
        cursor.execute("""
            SELECT country_name, COUNT(*) as cnt 
            FROM customers 
            GROUP BY country_name 
            ORDER BY cnt DESC, country_name
            FETCH FIRST 10 ROWS ONLY
        """)
        top_countries = cursor.fetchall()
        
        # Count countries with at least one customer
        countries_with_customers = len([c for c in country_stats if c[1] > 0])
        
        # Get max customers in a single country
        if top_countries:
            top_country_count = top_countries[0][1]
        
        cursor.close()
        conn.close()
    except Exception as e:
        error = str(e)
    
    return render_template_string(
        HTML_TEMPLATE, 
        customers=customers, 
        country_stats=country_stats,
        top_countries=top_countries,
        total_customers=total_customers,
        total_countries=total_countries,
        countries_with_customers=countries_with_customers,
        top_country_count=top_country_count,
        error=error, 
        db_host=DB_CONFIG['host'], 
        db_service=DB_CONFIG['service_name'],
        db_user=DB_CONFIG['user'],
        enumerate=enumerate
    )

@app.route('/health')
def health():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM customers")
        count = cursor.fetchone()[0]
        cursor.close()
        conn.close()
        return jsonify({'status': 'healthy', 'customer_count': count})
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500

@app.route('/api/customers')
def api_customers():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT customer_id, customer_name, email, country_name, created_at 
            FROM customers ORDER BY customer_id
        """)
        customers = [{
            'id': r[0], 
            'name': r[1], 
            'email': r[2],
            'country': r[3],
            'created_at': str(r[4])
        } for r in cursor.fetchall()]
        cursor.close()
        conn.close()
        return jsonify({'customers': customers, 'total': len(customers)})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/countries')
def api_countries():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT c.country_name, COUNT(cu.customer_name) as customer_count
            FROM country c
            LEFT JOIN customers cu ON c.country_name = cu.country_name
            GROUP BY c.country_name
            ORDER BY customer_count DESC, c.country_name
        """)
        countries = [{'name': r[0], 'customer_count': r[1]} for r in cursor.fetchall()]
        cursor.close()
        conn.close()
        return jsonify({'countries': countries, 'total': len(countries)})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/stats')
def api_stats():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM customers")
        total_customers = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM country")
        total_countries = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(DISTINCT country_name) FROM customers")
        active_countries = cursor.fetchone()[0]
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'total_customers': total_customers,
            'total_countries': total_countries,
            'active_countries': active_countries
        })
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
