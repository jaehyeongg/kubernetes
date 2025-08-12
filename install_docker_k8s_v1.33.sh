#!/bin/bash

# 에러 발생 시 스크립트 중단
set -e

echo "--- 시스템 업데이트 시작 ---"
sudo apt update -y
sudo apt upgrade -y
echo "--- 시스템 업데이트 완료 ---"

echo ""
echo "--- Docker 설치 시작 ---"

# Docker GPG 키 추가
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Docker APT 레포지토리 추가
echo \
  "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  \"$(. /etc/os-release && echo "$VERSION_CODENAME")\" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker 설치
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# 현재 사용자에게 docker 그룹 권한 부여 (재로그인 필요)
sudo usermod -aG docker "$USER"

echo "--- Docker 설치 완료. 현재 사용자에게 docker 그룹 권한이 부여되었습니다. 재로그인이 필요합니다. ---"

echo ""
echo "--- Kubernetes 설치 전 사전 설정 시작 (Swap 비활성화 및 브릿지 설정) ---"

# Swap 메모리 비활성화
sudo swapoff -a
# fstab에서 swap 설정 제거 (재부팅 시에도 유지)
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 브릿지 네트워크 설정 (컨테이너 간 통신 및 K8s 파드 네트워크)
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl 파라미터 설정 (쿠버네티스 요구사항)
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

echo "--- Kubernetes 설치 전 사전 설정 완료 ---"

echo ""
echo "--- Kubernetes (kubeadm, kubelet, kubectl) v1.33.x 설치 시작 ---"

# Google Cloud Public GPG 키 추가
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
# Kubernetes 1.33.x 버전을 위해 'v1.33'으로 경로 지정
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Kubernetes APT 레포지토리 추가
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Kubernetes 패키지 설치
# 특정 버전을 설치하려면 패키지 이름 뒤에 '=버전'을 붙여주세요. 예: kubelet=1.33.0-00
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "--- Kubernetes (kubeadm, kubelet, kubectl) v1.33.x 설치 완료 ---"

echo ""
echo "--- 설치 요약 ---"
echo "Docker 버전:"
docker --version
echo ""
echo "kubeadm 버전:"
kubeadm version
echo ""
echo "kubelet 버전:"
kubelet --version
echo ""
echo "kubectl 버전:"
kubectl version --client

echo ""
echo "설치가 완료되었습니다."
echo "--- 다음 단계 ---"
echo "1. Docker 그룹 권한 적용을 위해 **새 터미널을 열거나 재로그인**하세요."
echo "2. Kubernetes 클러스터를 초기화하려면 다음 명령을 실행하세요 (마스터 노드에서만):"
echo "   sudo kubeadm init --pod-network-cidr=10.244.0.0/16  # Calico를 사용하는 경우 (다른 CNI 사용 시 해당 CIDR 변경)"
echo "3. CNI (예: Calico)를 설치하세요:"
echo "   kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml"
echo "   (주의: CNI 버전은 Kubernetes v1.33과 호환되는 최신 안정 버전을 Calico 공식 문서에서 확인하고 적용하세요.)"
echo "4. 워커 노드를 클러스터에 조인시키려면 'kubeadm init' 명령 출력에 있는 'kubeadm join' 명령을 사용하세요."
