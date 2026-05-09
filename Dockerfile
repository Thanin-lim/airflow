

# 1. ใช้ Python เป็นฐาน
FROM python:3.10-slim

# 2. ตั้งโฟลเดอร์ทำงานใน Docker
WORKDIR /app

# 3. ก๊อปปี้ไฟล์ requirements และติดตั้ง
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. ก๊อปปี้โค้ดทั้งหมดลงไป
COPY . .

# 5. เปิด Port 5000
EXPOSE 5000

# 6. สั่งรันโปรแกรม
CMD ["python", "app.py"]