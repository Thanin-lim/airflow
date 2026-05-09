from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello():
    return "<h1>Hello from Flask in Docker!</h1><p>My Airflow project is working.</p>"

if __name__ == '__main__':
    # ต้องตั้ง host เป็น 0.0.0.0 เพื่อให้เข้าถึงจากนอก Docker ได้
    app.run(debug=True, host='0.0.0.0', port=5000)