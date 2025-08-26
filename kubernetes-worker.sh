#!/bin/bash
set -e  

# === 1. Basic system setup ===
sudo hostnamectl set-hostname worker-$(hostname | cut -d'-' -f2)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# === 2. Kernel modules and sysctl settings ===
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# === 3. Install container runtime (Docker) ===
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Configure systemd cgroup driver for Docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker

# === 4. Install Kubernetes (kubeadm, kubelet, kubectl) ===
sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
  | sudo tee /etc/apt/sources.list.d
