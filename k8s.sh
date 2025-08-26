#!/bin/bash
set -e

# ==============================
# 1. Basic System Setup
# ==============================
sudo hostnamectl set-hostname control

# Disable swap (K8s requirement)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Update system
sudo apt-get update -y
sudo apt-get upgrade -y

# ==============================
# 2. Install dependencies
# ==============================
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# ==============================
# 3. Install Docker
# ==============================
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

# Allow kubelet to use systemd as cgroup driver
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

sudo systemctl restart docker

# ==============================
# 4. Add Kubernetes Repository (NEW for Ubuntu 24.04)
# ==============================
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y

# ==============================
# 5. Install Kubernetes Components
# ==============================
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet service
sudo systemctl enable kubelet
sudo systemctl start kubelet

# ==============================
# 6. Initialize Kubernetes Control Plane
# ==============================
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Setup kubeconfig for regular user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# ==============================
# 7. Install Pod Network (Flannel)
# ==============================
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

echo "✅ Kubernetes Control Plane setup completed on Ubuntu 24.04!"
