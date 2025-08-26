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

# Configure Docker to use systemd cgroup driver
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

sudo systemctl restart docker

# ==============================
# 4. Add Kubernetes Repository (Ubuntu 24.04 - v1.30 stable)
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

sudo systemctl enable kubelet
sudo systemctl start kubelet

# ==============================
# 6. Initialize Kubernetes Control Plane with Docker
# ==============================
PRIVATE_IP=$(hostname -i)

sudo kubeadm reset -f
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///var/run/docker.sock \
  --apiserver-advertise-address=$PRIVATE_IP

# ==============================
# 7. Setup kubeconfig for user
# ==============================
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# ==============================
# 8. Install Flannel CNI
# ==============================
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# ==============================
# 9. Print Join Command for Workers
# ==============================
echo "===================================================="
echo "✅ Kubernetes Control Plane is ready!"
echo "👉 Use the following command on your workers to join:"
kubeadm token create --print-join-command
echo "===================================================="
