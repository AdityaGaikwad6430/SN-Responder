#!/bin/bash
# === 1. Basic system setup ===
sudo hostnamectl set-hostname control
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# === 2. Kernel modules and sysctl settings ===
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf > /dev/null
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf > /dev/null
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

# === 3. Install Docker ===
sudo apt-get update -y
sudo apt-get install -y docker.io
sudo systemctl enable --now docker

# === 4. Install cri-dockerd (v0.3.11 - stable) ===
wget -q https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.11/cri-dockerd-0.3.11.amd64.tgz
tar -xzf cri-dockerd-0.3.11.amd64.tgz
sudo mv -f cri-dockerd/cri-dockerd /usr/local/bin/
sudo chmod +x /usr/local/bin/cri-dockerd
sudo chown root:root /usr/local/bin/cri-dockerd

# === 5. Systemd service for cri-dockerd ===
cat <<EOF | sudo tee /etc/systemd/system/cri-dockerd.service > /dev/null
[Unit]
Description=CRI interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/cri-dockerd --container-runtime-endpoint=unix:///var/run/cri-dockerd.sock
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /etc/systemd/system/cri-dockerd.socket > /dev/null
[Unit]
Description=CRI dockerd socket

[Socket]
ListenStream=/var/run/cri-dockerd.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now cri-dockerd.service cri-dockerd.socket

# === 6. Install Kubernetes tools ===
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# === 7. Initialize Kubernetes with Docker (via cri-dockerd) ===
sudo kubeadm init \
  --cri-socket unix:///var/run/cri-dockerd.sock \
  --pod-network-cidr=192.168.0.0/16

# === 8. Setup kubectl for the current user ===
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# === 9. Apply Calico CNI plugin ===
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml

# === 10. Install Helm ===
curl https://baltocdn.com/helm/signing.asc | sudo gpg --dearmor -o /usr/share/keyrings/helm.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y helm

# === 11. Setup Migration Server (NFS server) ===
sudo apt-get install -y nfs-kernel-server
sudo mkdir -p /srv/nfs/kubedata
sudo chown nobody:nogroup /srv/nfs/kubedata
echo "/srv/nfs/kubedata *(rw,sync,no_subtree_check,no_root_squash,insecure)" | sudo tee -a /etc/exports
sudo exportfs -rav
sudo systemctl enable --now nfs-server
