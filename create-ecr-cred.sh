#!/bin/bash

# Delete existing secret to avoid errors during creation
kubectl delete secret ecr-cred --namespace tradein --ignore-not-found

# Create the new ECR pull secret
kubectl create secret docker-registry ecr-cred \
    --docker-server=564186749794.dkr.ecr.ap-south-1.amazonaws.com \
    --docker-username=AWS \
    --docker-password=$(aws ecr get-login-password --region ap-south-1) \
    --namespace=tradein

echo "ECR credentials secret 'ecr-cred' created successfully in the 'tradein' namespace."
