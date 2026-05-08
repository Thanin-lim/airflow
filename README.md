
## 🛠 Architecture & Tech Stack
** image ที่ใช้รันจะต้องเป็น OS Architecture  arm เท่านั้น หาก รันบน windows จะรันไม่ได้ เพราะว่าคนละ OS Architecture 
- **Apache Airflow**: จัดการและรัน Data Pipeline (DAGs)
- **Apache Spark**: ประมวลผลข้อมูลขนาดใหญ่ (Account Balances & Transactions)
- **MinIO**: ใช้เป็น Data Storage แทน AWS S3 (S3-compatible) (เนื่องจากฟรี)
- **PostgreSQL**: เก็บ Metadata ของ Airflow
- **Kubernetes (KinD)**: จัดการ Cluster สำหรับรัน Spark และบริการต่างๆ
- **Docker Compose**: สำหรับรัน Airflow และ Database ในเครื่องแบบง่ายๆ

---

##  Prerequisites
- [Docker](https://docs.docker.com/get-docker/)
- [KinD (Kubernetes in Docker)](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

---

##  Infrastructure Setup (การตั้งค่าระบบ)

### 1. สร้าง Kubernetes Cluster
สร้าง Cluster ใหม่สำหรับโปรเจกต์
```bash
kind create cluster --config kind-cluster.yaml
```

### 2. ติดตั้ง Ingress Controller
ติดตั้ง Nginx Ingress Controller เพื่อใช้เป็น Load Balancer และซ่อน IP
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

### 3. ตั้งค่า Host (Mapping IP)
หลังจาก Ingress ทำงานแล้ว ให้แก้ไขไฟล์ `/etc/hosts` เพื่อแมพ Local IP กับ Domain Name
```bash
sudo nano /etc/hosts 
# หรือ
sudo vim /etc/hosts
```
เพิ่มค่าต่อไปนี้ลงในไฟล์:
```text
127.0.0.1 airflow.localhost
127.0.0.1 spark.localhost
127.0.0.1 minio.localhost
```


### 4. Deploy automate Kubernetes Resources
สามารถรันสคริปต์ `deploy.sh` เพื่อทำการ Deploy Services ทั้งหมดได้อย่างอัตโนมัติ (โดยสคริปต์จะจัดการเรื่อง Dependency ให้ เช่น รอให้ PostgreSQL พร้อมทำงานก่อนที่จะ Deploy Airflow)
```bash
# ให้สิทธิ์การรัน 
chmod +x deploy.sh

# รันสคริปต์
./deploy.sh
```

### 5. Deploy manual Kubernetes Resources (Optional)
รันคำสั่งเพื่อ Deploy service ต่างๆ ใน Kubernetes
```bash
kubectl apply -f postgres.yaml
kubectl apply -f minio.yaml
kubectl apply -f spark.yaml
# deploy airflow หากต้องการรัน airflow บน kubernetes
kubectl apply -f airflow.yaml
kubectl apply -f ingress_platform.yaml
kubectl apply -f ingress_spark.yaml
kubectl apply -f ingress_airflow.yaml
```

---

---
## วิธีเข้าใช้ Services
- Airflow : http://airflow.localhost:30007
ีีusername admin
password admin
- Spark : http://spark.localhost:30008
- MinIO : http://minio.localhost:30004
username minio
password minio123

---

##  Airflow & Docker Setup (การรัน Airflow)

### 1. Build Airflow Image
ทำการ Build Docker Image สำหรับ Airflow โดยใช้ไฟล์ `Dockerfile`
```bash
docker build -t warvba22/airflow:0.1.0 .
```

*(Optional) Push image ขึ้น Registry:*
```bash
docker push warvba22/airflow:0.1.0
```



## วิธีการทดสอบ 
1. เข้า Airflow http://airflow.localhost:30007
2. run dag daily_account_reconciliation


## 💡 Technical Choices (เหตุผลในการเลือกใช้เทคโนโลยี)

### Why Apache Airflow? (ทำไมถึงเลือกใช้ Airflow)
- **Industry Standard Orchestrator:** Airflow เป็นเครื่องมือมาตรฐานที่ได้รับความนิยมสูงในการจัดการ Data Pipelines
- **Dependency Management:** สามารถเขียน DAG เพื่อจัดการลำดับการทำงาน เช่น สั่งให้ทำ Ingestion (PythonOperator) สำเร็จก่อน แล้วค่อยสั่งรัน Spark Job (BashOperator)
- **Monitoring & Alerting:** มี UI ที่ยอดเยี่ยมสำหรับการตรวจสอบสถานะของแต่ละ Task มีระบบ Retry อัตโนมัติ และแจ้งเตือนเมื่อเกิดความผิดพลาดได้ง่าย


### 2. รัน Airflow ด้วย Docker Compose
เริ่มการทำงานของ Airflow Webserver และ Scheduler
```bash
docker-compose up -d
```
หลังจากรันสำเร็จ คุณสามารถเข้าใช้งาน Airflow ได้ที่ `http://localhost:8080` (หรือ URL ตามที่เซตใน /etc/hosts และ ingress)
- **Username:** `admin`
- **Password:** `admin`

---




##  Pipeline Description (Data Pipeline )

Airflow DAG ชื่อ `daily_account_reconciliation_etl` ซึ่งจะรันงานประมวลผลข้อมูลผ่าน Apache Spark โดยมีขั้นตอนดังนี้
   1. อ่านข้อมูล **Account Balances** และ **Transactions** จาก **MinIO (s3a://data)**
   2. ตรวจสอบคุณภาพของข้อมูล (Data Quality Checks)
      - ค้นหาและแยกข้อมูลที่เป็น `Null`
      - ค้นหาและแยกข้อมูลที่ซ้ำซ้อน (Duplicates)
      - ตรวจสอบความถูกต้องของ `account_id` ในรายการเดินบัญชี
   3. ข้อมูลที่มีข้อผิดพลาด (Bad Data) จะถูกเขียนแยกเก็บไว้ใน MinIO (`bad_data/`)
   4. นำข้อมูลที่ถูกต้องมาคำนวณหายอดเงินฝาก-ถอนรวม (Net Movement) ของแต่ละบัญชีในแต่ละวัน
   5. เปรียบเทียบ `net_movement` กับยอด `eod_balance` ของบัญชี
   6. บันทึกผลการ Reconcile เป็น `reconcile_settled` หรือ `reconcile_pending_review` ลงใน MinIO (`reconciliation_results/`)

อธิบายรายละเอียดของ Airflow DAG ชื่อ `daily_account_reconciliation_etl` 
1. **Data Ingestion (`ingest_data_to_minio`):** Airflow จะใช้ `boto3` อ่านไฟล์ CSV จาก Local Volume แล้วอัปโหลดขึ้นไปที่ Landing Zone ใน MinIO โดยอัตโนมัติ (โฟลเดอร์ `daily_account_reconciliation/`)
2. **Data Processing & Quality Checks:** Spark Job จะเข้ามาอ่านข้อมูลจาก Landing Zone จากนั้นหาและแยกข้อมูลที่ผิดพลาด (Nulls, Duplicates, Invalid IDs) ออกมาเขียนแยกเก็บไว้ใน `bad_data/`
3. **Reconciliation & Calculation:** ข้อมูลที่ถูกต้องจะถูกนำมาคำนวณหายอดเงินฝาก-ถอนรวมของแต่ละบัญชีในแต่ละวัน นำไปเปรียบเทียบกับยอดบัญชี และบันทึกผล (reconcile_settled/reconcile_pending_review) ลงใน `reconciliation_results/`
4. **Data Archiving (`move_s3_files`):** หลังจากประมวลผลและเขียนผลลัพธ์เสร็จสิ้น Spark จะย้าย (Move) ไฟล์ข้อมูลตั้งต้นจาก Landing Zone ไปยังโฟลเดอร์ `archive/` เพื่อป้องกันการประมวลผลซ้ำและช่วยเคลียร์พื้นที่ทำงานให้พร้อมสำหรับวันถัดไป



---


## ☁️ Cloud Architecture (Production Deployment using EKS)
สำหรับการนำไปใช้งานจริงบน AWS โดยใช้ **Amazon EKS (Elastic Kubernetes Service)** สถาปัตยกรรมจะถูกออกแบบดังนี้

### Production Breakdown (AWS EKS):
1. **Orchestration:** ใช้ **Amazon EKS** ในการรัน Airflow (ผ่าน Helm Chart) เพื่อให้สามารถควบคุมและจัดการ Cluster เองได้ตามความต้องการขององค์กร
2. **Compute:** รัน Spark บน **EKS** โดยใช้ **EMR on EKS** หรือ **Spark Operator** เพื่อให้สามารถขยายจำนวน Node (Scaling) ได้ตามปริมาณงานในแต่ละวัน
3. **Data Storage:** ใช้ **Amazon S3** เป็น Data Lake (Durability 99.999999999%) แยก Bucket ตามโซนการทำงาน
4. **Metadata Store:** จัดเก็บ Airflow Metadata ลงใน **Amazon RDS (PostgreSQL)** แบบ Multi-AZ เพื่อความปลอดภัยและ High Availability
5. **Monitoring & Security:** ใช้ **CloudWatch** และ **Managed Prometheus/Grafana** สำหรับ Monitoring และใช้ **IAM Roles for Service Accounts (IRSA)** ในการควบคุมสิทธิ์การเข้าถึง S3




*(หมายเหตุ: สามารถนำ Architecture นี้ไปปรับใช้กับ Cloud Provider ค่ายอื่นได้ เช่น บน GCP สามารถใช้ Cloud Composer + Dataproc + GCS หรือบน Azure สามารถใช้ Azure Data Factory/Airflow on AKS + Databricks + ADLS)*