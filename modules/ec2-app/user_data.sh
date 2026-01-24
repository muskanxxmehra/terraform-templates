#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -x

echo "=== Starting App Server Setup ==="

apt-get update -y
apt-get install -y python3 python3-pip python3-venv python3-dev gcc wget unzip
apt-get install -y libaio1t64 || apt-get install -y libaio1

pip3 install --break-system-packages --ignore-installed typing_extensions blinker werkzeug itsdangerous
pip3 install --break-system-packages oracledb flask gunicorn

mkdir -p /opt/flask-app

# Create app.py
cat > /opt/flask-app/app.py << 'APPEOF'
from flask import Flask, jsonify, render_template_string
import oracledb, os

app = Flask(__name__)
DB = {
    'host': os.environ.get('DB_HOST', 'localhost'),
    'port': int(os.environ.get('DB_PORT', '1521')),
    'service': os.environ.get('DB_SERVICE', 'XEPDB1'),
    'user': os.environ.get('DB_USER', 'appuser'),
    'password': os.environ.get('DB_PASSWORD', 'password')
}

HTML = """
<!DOCTYPE html>
<html><head><title>Customer Management Demo</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:Arial,sans-serif;background:linear-gradient(135deg,#667eea,#764ba2);min-height:100vh;padding:20px}
.c{max-width:1100px;margin:0 auto}
.card{background:#fff;border-radius:10px;padding:20px;margin-bottom:20px;box-shadow:0 4px 15px rgba(0,0,0,.2)}
h1{color:#333;font-size:1.8em;margin-bottom:5px}
.sub{color:#666;margin-bottom:15px}
.badge{display:inline-block;background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;padding:6px 15px;border-radius:15px;font-size:.85em}
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:15px;margin-bottom:20px}
.stat{background:#fff;border-radius:10px;padding:20px;text-align:center;box-shadow:0 4px 15px rgba(0,0,0,.1)}
.stat .n{font-size:2em;font-weight:700;color:#667eea}
.stat .l{color:#666;font-size:.9em}
.conn{background:#f8f9fa;padding:10px 15px;border-radius:8px;font-size:.9em;margin-bottom:15px}
.conn span{color:#667eea;font-family:monospace}
.ok{color:#28a745}.err{color:#dc3545}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}
@media(max-width:800px){.grid,.stats{grid-template-columns:1fr}}
table{width:100%%;border-collapse:collapse}
th,td{padding:10px;text-align:left;border-bottom:1px solid #eee}
th{background:#f8f9fa;color:#555;font-size:.85em}
.tbl{max-height:300px;overflow-y:auto}
.tag{background:#e9d8fd;color:#6b46c1;padding:3px 8px;border-radius:10px;font-size:.8em}
.em{color:#667eea;font-size:.85em}
h2{background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;padding:12px 15px;margin:-20px -20px 15px;border-radius:10px 10px 0 0;font-size:1.1em}
.foot{text-align:center;color:rgba(255,255,255,.8);padding:15px;font-size:.85em}
</style></head>
<body><div class="c">
<div class="card"><h1>Customer Management System</h1><p class="sub">Demo Application - Customer to Country Mapping</p><span class="badge">Oracle XE 21c + Flask + Python</span></div>
<div class="stats">
<div class="stat"><div class="n">{{tc}}</div><div class="l">Customers</div></div>
<div class="stat"><div class="n">{{tco}}</div><div class="l">Countries</div></div>
<div class="stat"><div class="n">{{ac}}</div><div class="l">Active Regions</div></div>
<div class="stat"><div class="n">{{mx}}</div><div class="l">Max/Country</div></div>
</div>
<div class="card">
<div class="conn"><b>Database:</b> <span>{{dh}}:1521/{{ds}}</span> | <b>User:</b> <span>{{du}}</span> | <b>Status:</b> {% if er %}<span class="err">Error</span>{% else %}<span class="ok">Connected</span>{% endif %}</div>
{% if er %}<p class="err">{{er}}</p>{% endif %}
</div>
<div class="grid">
<div class="card"><h2>Countries ({{tco}})</h2><div class="tbl"><table><tr><th>Country</th><th>Customers</th></tr>{% for r in cs %}<tr><td>{{r[0]}}</td><td><b>{{r[1]}}</b></td></tr>{% endfor %}</table></div></div>
<div class="card"><h2>Top Regions</h2><div class="tbl"><table><tr><th>#</th><th>Country</th><th>Count</th></tr>{% for r in tp %}<tr><td><b>{{loop.index}}</b></td><td>{{r[0]}}</td><td><b>{{r[1]}}</b></td></tr>{% endfor %}</table></div></div>
</div>
<div class="card"><h2>Customer Directory ({{tc}} Records)</h2><div class="tbl"><table><tr><th>ID</th><th>Name</th><th>Email</th><th>Country</th><th>Created</th></tr>{% for r in cu %}<tr><td>{{r[0]}}</td><td><b>{{r[1]}}</b></td><td class="em">{{r[2]}}</td><td><span class="tag">{{r[3]}}</span></td><td>{{r[4]}}</td></tr>{% endfor %}</table></div></div>
<div class="foot">Demo Application | Oracle XE 21c | Flask Framework</div>
</div></body></html>
"""

def conn():
    return oracledb.connect(user=DB['user'],password=DB['password'],dsn=f"{DB['host']}:{DB['port']}/{DB['service']}")

@app.route('/')
def index():
    cu,cs,tp,tc,tco,ac,mx,er=[],[],[],0,0,0,0,None
    try:
        c=conn();cur=c.cursor()
        cur.execute("SELECT customer_id,customer_name,email,country_name,TO_CHAR(created_at,'YYYY-MM-DD HH24:MI') FROM customers ORDER BY customer_id")
        cu=cur.fetchall();tc=len(cu)
        cur.execute("SELECT c.country_name,COUNT(cu.customer_name) FROM country c LEFT JOIN customers cu ON c.country_name=cu.country_name GROUP BY c.country_name ORDER BY c.country_name")
        cs=cur.fetchall();tco=len(cs);ac=len([x for x in cs if x[1]>0])
        cur.execute("SELECT country_name,COUNT(*) cnt FROM customers GROUP BY country_name ORDER BY cnt DESC FETCH FIRST 10 ROWS ONLY")
        tp=cur.fetchall();mx=tp[0][1] if tp else 0
        cur.close();c.close()
    except Exception as e:er=str(e)
    return render_template_string(HTML,cu=cu,cs=cs,tp=tp,tc=tc,tco=tco,ac=ac,mx=mx,er=er,dh=DB['host'],ds=DB['service'],du=DB['user'])

@app.route('/health')
def health():
    try:
        c=conn();c.close()
        return jsonify({'status':'healthy'})
    except Exception as e:
        return jsonify({'status':'unhealthy','error':str(e)}),500

@app.route('/api/customers')
def api_cust():
    try:
        c=conn();cur=c.cursor()
        cur.execute("SELECT customer_id,customer_name,email,country_name,created_at FROM customers ORDER BY customer_id")
        r=[{'id':x[0],'name':x[1],'email':x[2],'country':x[3],'created':str(x[4])} for x in cur.fetchall()]
        cur.close();c.close()
        return jsonify({'customers':r,'total':len(r)})
    except Exception as e:
        return jsonify({'error':str(e)}),500

@app.route('/api/countries')
def api_ctry():
    try:
        c=conn();cur=c.cursor()
        cur.execute("SELECT c.country_name,COUNT(cu.customer_name) FROM country c LEFT JOIN customers cu ON c.country_name=cu.country_name GROUP BY c.country_name ORDER BY c.country_name")
        r=[{'name':x[0],'customers':x[1]} for x in cur.fetchall()]
        cur.close();c.close()
        return jsonify({'countries':r,'total':len(r)})
    except Exception as e:
        return jsonify({'error':str(e)}),500

if __name__=='__main__':
    app.run(host='0.0.0.0',port=5000)
APPEOF

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
