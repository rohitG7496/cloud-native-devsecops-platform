# cloud-native-devsecops-platform
This Project demonstrates production-grade Cloud Native DevSecOps platform with automated Kubernetes provisioning (kubeadm + Ansible ) on EC2, Vault-based External secrets mgmt, ArgoCD GitOps deployments, Karpenter autoscaling on a self-managed kubernetes kubeadm based cluster, and enterprise CI/CD pipelines demonstrating real-world architecture and lifecycle automation.

###### Karpenter setup on Kubeadm Cluster

# Setup Environment Variables for Karpenter
```
export CLUSTER_NAME="<YOUR-ClUSTER-NAME>"
export KARPENTER_VERSION="1.9.0" # Check for latest
export AWS_REGION="<AWS-REGION>"
export CLUSTER_ENDPOINT="<CLUSTER-ENDPOINT>" # add your cluster endpoint
```

# Install Karpenter
```
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" \
  --namespace karpenter --create-namespace \
  --set settings.clusterName=${CLUSTER_NAME} \
  --set settings.clusterEndpoint=${CLUSTER_ENDPOINT} \
  --set settings.interruptionQueue="" \
  --set controller.resources.requests.cpu=200m \
  --set controller.resources.requests.memory=256Mi \
  --set dnsPolicy=Default \
  --set settings.featureGates.nodeRepair=false \
  --wait --timeout 5m
```

# TradeIn DevSecOps Project

A full-stack application for buying, selling, and donating products, designed with DevSecOps best practices and containerized for easy deployment on kubernetes cluster production environment with CI/CD pipeline and GitOps integration with ArgoCD.

## 🚀 Features
- **Buy/Sell/Donate**: Complete marketplace for trading items.
- **User Profiles**: Manage accounts and track Trade-coins.
- **Image Storage**: Integrated with Cloudinary for secure image uploads.
- **Containerized**: Fully orchestrated using Docker Compose.
- **Nginx Reverse Proxy**: Secure and efficient routing for Frontend and API.

## 🛠 Tech Stack
- **Frontend**: React (Material UI)
- **Backend**: Django (Python)
- **Database**: MySQL 8.0
- **Storage**: Cloudinary
- **Server/Proxy**: Nginx
- **Containerization**: Docker & Docker Compose

## 📦 Deployment Instructions

### Prerequisites
- Docker and Docker Compose installed.
- Cloudinary account for image storage.
- Port 80 and 8000 (internal) available.

### Setup Steps

1. **Clone the Repository**
   ```bash
   git clone https://github.com/rohitG7496/tradeIn-devsecops.git
   cd tradeIn-devsecops
   ```

2. **Configure Environment Variables**
   Create a `.env` file in the `Backend/` directory:
   ```bash
   nano Backend/.env
   ```
   Add the following configuration (replace placeholders with real keys):
   ```ini
   DEBUG=1
   SECRET_KEY=your_random_secret_key
   
   DB_NAME=tradein_db
   DB_USER=root
   DB_PASSWORD=your_db_password
   DB_HOST=db
   DB_PORT=3306
   
   CLOUD_NAME=your_cloudinary_name
   API_KEY=your_cloudinary_api_key
   API_SECRET=your_cloudinary_api_secret
   ```

3. **Deploy with Docker Compose**
   ```bash
   sudo docker compose up -d --build
   ```

4. **Run Database Migrations**
   ```bash
   sudo docker compose exec backend python manage.py migrate
   ```

5. **Access the Application**
   Open your browser and go to `http://localhost` (or your Server IP).

## 🛠 Troubleshooting

### Port 80 Already in Use
If you get a "bind: address already in use" error for port 80, kill the existing process:
```bash
sudo fuser -k 80/tcp
```

### Database Authentication Error
If you change the DB password in `.env` after initialization, you must clear the persistent volume:
```bash
sudo docker compose down -v
sudo docker compose up -d
```

### Images Not Uploading
Ensure your Cloudinary keys in `Backend/.env` are correct and that the `docker-compose.yml` uses the `env_file` property to load them.

## 🤝 Contributing
Feel free to fork this project and submit pull requests for any DevSecOps or K8S improvements!
