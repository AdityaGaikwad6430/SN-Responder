#!/bin/bash

# === 1. Set hostname (optional, but helpful)
sudo hostnamectl set-hostname worker

# === 2. Disable swap and load kernel modules
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# === 3. Set sysctl params
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

# === 4. Install Docker
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable docker --now

# === 5. Install cri-dockerd (v0.3.11 - stable)
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.11/cri-dockerd-0.3.11.amd64.tgz
tar -xvf cri-dockerd-0.3.11.amd64.tgz
sudo mv cri-dockerd/cri-dockerd /usr/local/bin/
sudo chmod +x /usr/local/bin/cri-dockerd
sudo chown root:root /usr/local/bin/cri-dockerd

# === 6. Create systemd unit files
cat <<EOF | sudo tee /etc/systemd/system/cri-dockerd.service
[Unit]
Description=CRI interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/cri-dockerd --container-runtime-endpoint fd://
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /etc/systemd/system/cri-dockerd.socket
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

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now cri-dockerd.socket cri-dockerd.service

# === 7. Install Kubernetes tools (v1.30)
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gpg
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
