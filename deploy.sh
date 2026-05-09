#!/bin/bash

set -e

echo " Starting Kubernetes Deployment..."

echo " Deploying PostgreSQL..."
kubectl apply -f postgres.yaml

echo " Waiting for PostgreSQL pod to be ready..."
kubectl rollout status deployment/postgres --timeout=120s

echo " PostgreSQL is ready!"

echo "config minio apply "
kubectl apply -f config.yaml
echo " Deploying MinIO..."
kubectl apply -f minio.yaml

echo " Deploying Apache Spark..."
kubectl apply -f spark.yaml

echo " Deploying Apache Airflow..."
kubectl apply -f airflow.yaml

echo " Deploying Ingress configurations..."
kubectl apply -f ingress_platform.yaml
kubectl apply -f ingress_spark.yaml
kubectl apply -f ingress_airflow.yaml

echo " All resources have been deployed successfully!"
