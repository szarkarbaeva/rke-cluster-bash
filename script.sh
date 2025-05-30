#!/bin/bash

read -p "Enter master IP: " master_ip
read -p "Enter worker1 IP: " worker1_ip
read -p "Enter worker2 IP: " worker2_ip

pubkey=$(cat ~/.ssh/id_rsa.pub)
vms_ip=("$master_ip" "$worker1_ip" "$worker2_ip")  

function install_rke() {
wget https://github.com/rancher/rke/releases/download/v1.8.3/rke_linux-amd64
mv rke_linux-amd64 rke
chmod +x rke
sudo mv rke /usr/local/bin
}

function install_kubectl() {
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin
}

function docker() {
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

VERSION_STRING=5:24.0.9-1~ubuntu.22.04~jammy

sudo apt-get install docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin -y
} 

function prepare_vms() {
	for ip in "${vms_ip[@]}" 
	do
		scp vm.sh ubuntu@$ip:
		ssh ubuntu@$ip bash vm.sh
		ssh ubuntu@$ip "echo '$pubkey' | sudo tee -a /home/rke/.ssh/authorized_keys"
	done
}

function create_cluster_file() {
	cp cluster.yml.template cluster.yml
	sed -i "s/MASTER_IP/$master_ip/" cluster.yml
	sed -i "s/WORKER1_IP/$worker1_ip/" cluster.yml
	sed -i "s/WORKER2_IP/$worker2_ip/" cluster.yml
}

function create_cluster() {
	rke up
	sudo mkdir ~/.kube
	sudo mv kube_config_cluster.yml ~/.kube/config
	kubectl get nodes
}

function create_sc() {
	kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
} 

install_rke
install_kubectl
# docker
prepare_vms
create_cluster_file
create_cluster
create_sc
