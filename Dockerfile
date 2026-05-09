FROM --platform=linux/amd64 apache/airflow:2.7.1-python3.9

USER root

RUN apt-get update && apt-get install -y \
    default-jdk \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME /usr/lib/jvm/default-java

USER airflow

# ติดตั้ง requirements
COPY --chown=airflow:root requirements.txt .
RUN pip install --no-cache-dir "apache-airflow==2.7.1" -r requirements.txt