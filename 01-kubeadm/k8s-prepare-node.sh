#!/bin/bash

# 이 스크립트는 Rocky Linux 10 노드를 Kubernetes 배포를 위해 준비합니다.
# 컨테이너 런타임으로 containerd 2.2.0 (바이너리)을 사용합니다.
# 이 스크립트는 root 권한으로 실행해야 합니다.

# set -e: 명령어 실행 중 오류가 발생하면 즉시 스크립트를 중단합니다.
# 이렇게 하면 중간에 실패한 상태로 진행되는 것을 방지할 수 있습니다.
set -e

# ========================================
# 변수 정의 섹션
# ========================================

# SWAP_FILE: 스왑 파일 경로 (필요시 삭제하기 위한 변수)
SWAP_FILE="/swap.img"

# CONTAINERD_VERSION: 설치할 containerd 버전
# containerd는 컨테이너 런타임으로, Kubernetes가 Pod를 실행하기 위해 필요합니다.
CONTAINERD_VERSION="2.2.0"

# RUNC_VERSION: 설치할 runc 버전
# runc는 OCI(Open Container Initiative) 표준을 따르는 컨테이너 런타임입니다.
# containerd가 실제로 컨테이너를 실행할 때 내부적으로 runc를 사용합니다.
RUNC_VERSION="1.2.0"

# CNI_PLUGINS_VERSION: 설치할 CNI 플러그인 버전
# CNI(Container Network Interface) 플러그인은 Kubernetes Pod의 네트워크를 구성합니다.
# Pod가 생성될 때 네트워크 인터페이스를 할당하고, 삭제될 때 정리합니다.
CNI_PLUGINS_VERSION="1.5.1"

# ARCH: 시스템 아키텍처 (amd64 또는 arm64)
# uname -m: 시스템의 하드웨어 아키텍처를 확인합니다.
# x86_64는 amd64로, aarch64는 arm64로 매핑됩니다.
ARCH="amd64"
if [ "$(uname -m)" = "aarch64" ]; then ARCH="arm64"; fi

# ========================================
# 노드 설정 파일 읽기 섹션
# ========================================

# SCRIPT_DIR: 스크립트가 위치한 디렉토리 경로를 가져옵니다.
# ${BASH_SOURCE[0]}: 현재 실행 중인 스크립트의 경로
# dirname: 경로에서 디렉토리 부분만 추출
# cd와 pwd를 사용하여 절대 경로로 변환합니다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# NODES_FILE: 노드 설정 파일의 경로
# 스크립트와 같은 디렉토리에 있는 k8s-nodes.txt 파일을 사용합니다.
NODES_FILE="${SCRIPT_DIR}/k8s-nodes.txt"

# 스크립트가 다른 위치에서 실행된 경우, 현재 디렉토리에서도 찾아봅니다.
# [ ! -f "$NODES_FILE" ]: 파일이 존재하지 않으면
if [ ! -f "$NODES_FILE" ]; then
    NODES_FILE="./k8s-nodes.txt"
fi

# 여전히 파일을 찾지 못한 경우, 오류 메시지를 출력하고 스크립트를 종료합니다.
# exit 1: 오류 코드 1로 종료 (0은 성공, 1 이상은 오류)
if [ ! -f "$NODES_FILE" ]; then
    echo "오류: k8s-nodes.txt 파일을 찾을 수 없습니다!"
    echo "스크립트와 같은 디렉토리에 k8s-nodes.txt 파일이 있는지 확인하세요."
    echo "예상 위치: ${SCRIPT_DIR}/k8s-nodes.txt"
    exit 1
fi

# 노드 설정 파일에서 호스트 엔트리를 읽어옵니다.
echo "노드 설정 파일 읽는 중: ${NODES_FILE}"

# HOSTS_ENTRIES: 호스트 엔트리를 저장할 배열 변수
# 배열은 여러 값을 저장할 수 있는 변수 타입입니다.
HOSTS_ENTRIES=()

# while 루프: 파일의 각 줄을 읽어서 처리합니다.
# IFS=: Internal Field Separator를 빈 값으로 설정하여 줄바꿈을 기준으로 분리
# read -r: 백슬래시를 이스케이프 문자로 해석하지 않고 그대로 읽습니다.
# || [ -n "$line" ]: 파일 끝에 빈 줄이 있어도 처리하도록 합니다.
while IFS= read -r line || [ -n "$line" ]; do
    # 빈 줄이거나 주석(#으로 시작하는 줄)은 건너뜁니다.
    # [[ -z "$line" ]]: 변수가 비어있으면 true
    # [[ "$line" =~ ^[[:space:]]*# ]]: 줄이 공백 후 #으로 시작하면 true (정규표현식)
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
        continue  # 다음 줄로 넘어갑니다.
    fi
    
    # 줄 앞뒤의 공백을 제거합니다.
    # sed 's/^[[:space:]]*//': 줄 앞의 공백 제거
    # sed 's/[[:space:]]*$//': 줄 뒤의 공백 제거
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # 공백을 제거한 후에도 내용이 있으면 배열에 추가합니다.
    if [ -n "$line" ]; then
        HOSTS_ENTRIES+=("$line")  # 배열에 요소 추가
    fi
done < "$NODES_FILE"  # 파일을 입력으로 사용

# 읽어온 엔트리가 있는지 검증합니다.
# ${#HOSTS_ENTRIES[@]}: 배열의 요소 개수
if [ ${#HOSTS_ENTRIES[@]} -eq 0 ]; then
    echo "오류: ${NODES_FILE} 파일에서 유효한 호스트 엔트리를 찾을 수 없습니다."
    echo "파일 형식을 확인하세요. 형식: IP주소 호스트명"
    exit 1
fi

echo "설정 파일에서 ${#HOSTS_ENTRIES[@]}개의 노드를 찾았습니다."

# ========================================
# 사전 검증 섹션
# ========================================

# root 권한으로 실행 중인지 확인합니다.
# $EUID: Effective User ID (0이면 root)
# [[ $EUID -ne 0 ]]: root가 아니면 true
if [[ $EUID -ne 0 ]]; then
   echo "이 스크립트는 root 권한으로 실행해야 합니다."
   exit 1
fi

# 운영체제가 Rocky Linux인지 확인합니다.
# /etc/rocky-release: Rocky Linux의 릴리스 정보 파일
# [ ! -f ... ]: 파일이 존재하지 않으면 true
if [ ! -f /etc/rocky-release ]; then
    echo "이 스크립트는 Rocky Linux용으로 설계되었습니다."
    exit 1
fi

# Rocky Linux 버전이 10인지 확인합니다.
# grep -oP: Perl 정규표현식 사용, -o는 매칭된 부분만 출력
# \K: lookbehind assertion, 이전 부분은 출력하지 않음
# || echo "0": grep이 실패하면 기본값 "0" 사용
ROCKY_VERSION=$(grep -oP 'Rocky Linux release \K[0-9]+' /etc/rocky-release || echo "0")

# 버전이 10이 아니면 오류 메시지를 출력하고 종료합니다.
if [ "$ROCKY_VERSION" != "10" ]; then
    echo "이 스크립트는 Rocky Linux 10용으로 설계되었습니다. (감지된 버전: Rocky Linux $ROCKY_VERSION)"
    exit 1
fi

echo "Rocky Linux 10용 Kubernetes 노드 준비를 시작합니다..."

# ========================================
# 0.1 /etc/hosts 파일 설정
# ========================================

echo "/etc/hosts 파일 설정 중..."

# 기존 hosts 파일을 백업합니다.
# cp: 파일 복사 명령어
# /etc/hosts.bak: 백업 파일
cp /etc/hosts /etc/hosts.bak

# 기본 localhost 엔트리로 시작하는 새로운 hosts 파일을 생성합니다.
# cat <<EOF: heredoc 문법, EOF까지의 내용을 파일에 씁니다.
# > : 리다이렉션으로 파일에 쓰기 (덮어쓰기)
cat <<EOF > /etc/hosts
127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4
::1 localhost localhost.localdomain localhost6 localhost6.localdomain6

# 아래 줄들은 k8s-prepare-node.sh에 의해 추가되었습니다.
# 노드 설정 파일: ${NODES_FILE}
EOF

# 설정 파일에서 읽어온 각 호스트 엔트리를 /etc/hosts에 추가합니다.
# for 루프: 배열의 각 요소를 순회합니다.
# "${HOSTS_ENTRIES[@]}": 배열의 모든 요소
for entry in "${HOSTS_ENTRIES[@]}"; do
    # >> : 파일에 추가 (append)
    echo "$entry" >> /etc/hosts
    echo "  추가됨: $entry"
done

# ========================================
# 1. Swap 비활성화
# ========================================

echo "Swap 비활성화 중..."

# swapoff -a: 모든 스왑 장치를 비활성화합니다.
# Kubernetes는 성능과 안정성을 위해 swap을 비활성화해야 합니다.
# swap이 활성화되어 있으면 메모리 부족 시 프로세스가 swap으로 이동하는데,
# 이는 예측 불가능한 성능 저하를 일으킬 수 있습니다.
swapoff -a

# /etc/fstab 파일에서 swap 관련 줄을 주석 처리합니다.
# sed -i: 파일을 직접 수정 (in-place editing)
# /[[:space:]]swap[[:space:]]/: 공백으로 둘러싸인 "swap" 문자열 찾기
# s/^\(.*\)$/#\1/: 줄 전체를 주석 처리 (# 추가)
sed -i '/[[:space:]]swap[[:space:]]/ s/^\(.*\)$/#\1/' /etc/fstab

# 스왑 파일이 존재하면 삭제합니다.
# [ -f "$SWAP_FILE" ]: 파일이 존재하면 true
if [ -f "$SWAP_FILE" ]; then
    rm -f "$SWAP_FILE"  # -f: 강제 삭제 (존재하지 않아도 오류 없음)
fi

# ========================================
# 2. 필요한 커널 모듈 로드
# ========================================

echo "필요한 커널 모듈 로드 중..."

# overlay: 오버레이 파일시스템 모듈
# 컨테이너의 레이어드 파일시스템을 위해 필요합니다.
# 여러 이미지 레이어를 하나의 통합된 파일시스템으로 보여줍니다.

# br_netfilter: 브리지 네트워크 필터링 모듈
# Kubernetes가 브리지 네트워크에서 iptables 규칙을 적용하기 위해 필요합니다.
# Pod 간 통신과 외부 통신을 제어합니다.

# /etc/modules-load.d/k8s.conf: 시스템 부팅 시 자동으로 로드할 모듈 목록
# tee: 표준 출력과 파일에 동시에 쓰기
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# modprobe: 커널 모듈을 즉시 로드합니다.
# 현재 세션에서 바로 사용할 수 있도록 합니다.
modprobe overlay
modprobe br_netfilter

# ========================================
# 3. sysctl 파라미터 설정
# ========================================

echo "sysctl 파라미터 설정 중..."

# sysctl: 커널 파라미터를 설정하는 명령어
# /etc/sysctl.d/k8s.conf: Kubernetes 관련 네트워크 설정 파일

# net.bridge.bridge-nf-call-iptables = 1
# 브리지 네트워크의 트래픽도 iptables 규칙을 적용하도록 설정합니다.
# Kubernetes는 iptables를 사용하여 서비스 로드밸런싱과 네트워크 정책을 구현합니다.

# net.bridge.bridge-nf-call-ip6tables = 1
# IPv6 트래픽에도 동일하게 적용합니다.

# net.ipv4.ip_forward = 1
# IP 포워딩을 활성화합니다. Pod 간 통신을 위해 필요합니다.
# 한 네트워크 인터페이스로 들어온 패킷을 다른 인터페이스로 전달할 수 있게 합니다.
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# sysctl --system: 모든 sysctl 설정 파일을 적용합니다.
# 방금 만든 설정이 즉시 적용됩니다.
sysctl --system

# ========================================
# 4. 필수 패키지 설치
# ========================================

echo "필수 패키지 설치 중..."

# dnf: Rocky Linux의 패키지 관리자 (yum의 후속 버전)
# install -y: 설치 확인 질문에 자동으로 yes로 답변

# curl: URL로 데이터를 전송/수신하는 도구 (HTTP 요청)
# wget: 웹에서 파일을 다운로드하는 도구
# tar: 아카이브 파일을 압축/해제하는 도구
# gzip: 파일 압축 도구
dnf install -y curl wget tar gzip

# ========================================
# 5. containerd 설치 (바이너리)
# ========================================

echo "containerd ${CONTAINERD_VERSION} 설치 중 (바이너리)..."

# /tmp 디렉토리로 이동합니다.
# 다운로드한 파일을 임시로 저장하기 위함입니다.
cd /tmp

# wget: GitHub에서 containerd 바이너리 아카이브를 다운로드합니다.
# ${CONTAINERD_VERSION}: 변수 값으로 버전 번호가 치환됩니다.
# ${ARCH}: 시스템 아키텍처 (amd64 또는 arm64)
wget "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"

# tar: 아카이브 파일을 압축 해제합니다.
# C: 압축 해제 전 디렉토리 변경
# z: gzip 압축 해제
# x: 압축 해제 (extract)
# v: 상세 출력 (verbose)
# f: 파일 지정
# /usr/local: 압축 해제할 대상 디렉토리 (시스템 바이너리 설치 위치)
tar Czxvf /usr/local "containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"

# 다운로드한 아카이브 파일을 삭제합니다.
# rm -f: 파일 삭제 (존재하지 않아도 오류 없음)
rm -f "containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"

# containerd systemd 서비스 파일을 다운로드합니다.
# systemd: Linux 시스템 및 서비스 관리자
# 서비스 파일을 통해 containerd를 시스템 서비스로 등록할 수 있습니다.
# -O: 출력 파일명 지정
wget -O /etc/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

# containerd 설정 디렉토리를 생성합니다.
# mkdir -p: 디렉토리가 없으면 생성, 이미 있으면 오류 없이 통과
mkdir -p /etc/containerd

# containerd의 기본 설정 파일을 생성합니다.
# config default: 기본 설정을 출력
# > : 표준 출력을 파일로 리다이렉션 (덮어쓰기)
/usr/local/bin/containerd config default > /etc/containerd/config.toml

# SystemdCgroup을 활성화합니다.
# Kubernetes는 systemd cgroup 드라이버를 사용해야 합니다.
# cgroup: 프로세스 그룹의 리소스 사용량을 제한하고 관리하는 Linux 커널 기능
# sed -i: 파일을 직접 수정
# 's/SystemdCgroup = false/SystemdCgroup = true/': false를 true로 변경
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# pause 이미지 버전을 업데이트합니다.
# pause 컨테이너는 Pod의 네트워크 네임스페이스를 유지하는 특수한 컨테이너입니다.
# 모든 Pod는 pause 컨테이너를 공유합니다.
# |: 파이프, sed의 구분자로 사용 (URL에 /가 있어서)
sed -i 's|sandbox_image = "registry.k8s.io/pause:3.8"|sandbox_image = "registry.k8s.io/pause:3.9"|' /etc/containerd/config.toml

# systemd 데몬을 다시 로드합니다.
# 새로 추가된 서비스 파일을 인식하도록 합니다.
systemctl daemon-reload

# containerd 서비스를 재시작합니다.
# 설정 변경사항을 적용하기 위함입니다.
systemctl restart containerd

# containerd 서비스를 부팅 시 자동 시작되도록 설정합니다.
# enable: 서비스를 활성화하여 시스템 부팅 시 자동으로 시작
systemctl enable containerd

# ========================================
# 6. runc 설치 (바이너리)
# ========================================

echo "runc ${RUNC_VERSION} 설치 중 (바이너리)..."

# /tmp 디렉토리로 이동합니다.
cd /tmp

# GitHub에서 runc 바이너리를 다운로드합니다.
# runc는 단일 바이너리 파일로 제공됩니다.
wget "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.${ARCH}"

# install: 파일을 복사하고 권한을 설정합니다.
# -m 755: 파일 권한을 755로 설정 (소유자는 읽기/쓰기/실행, 그룹/기타는 읽기/실행)
# /usr/local/sbin/runc: 시스템 바이너리 디렉토리에 설치
install -m 755 runc.${ARCH} /usr/local/sbin/runc

# 다운로드한 파일을 삭제합니다.
rm -f runc.${ARCH}

# ========================================
# 7. CNI 플러그인 설치 (바이너리)
# ========================================

echo "CNI 플러그인 ${CNI_PLUGINS_VERSION} 설치 중 (바이너리)..."

# /tmp 디렉토리로 이동합니다.
cd /tmp

# GitHub에서 CNI 플러그인 아카이브를 다운로드합니다.
wget "https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-v${CNI_PLUGINS_VERSION}.tgz"

# CNI 플러그인 바이너리 디렉토리를 생성합니다.
# /opt/cni/bin: CNI 플러그인의 표준 설치 위치
# Kubernetes는 이 경로에서 CNI 플러그인을 찾습니다.
mkdir -p /opt/cni/bin

# CNI 플러그인 아카이브를 압축 해제합니다.
tar Czxvf /opt/cni/bin "cni-plugins-linux-${ARCH}-v${CNI_PLUGINS_VERSION}.tgz"

# 다운로드한 아카이브 파일을 삭제합니다.
rm -f "cni-plugins-linux-${ARCH}-v${CNI_PLUGINS_VERSION}.tgz"

# ========================================
# 8. Kubernetes 도구 설치
# ========================================

echo "Kubernetes 도구 설치 중..."

# Kubernetes 공식 RPM 저장소를 추가합니다.
# cat <<EOF: heredoc으로 여러 줄의 내용을 파일에 씁니다.
# tee: 표준 출력과 파일에 동시에 쓰기
# /etc/yum.repos.d/kubernetes.repo: yum/dnf 저장소 설정 파일

# [kubernetes]: 저장소 섹션 이름
# name: 저장소 설명
# baseurl: 패키지가 있는 URL
# enabled=1: 저장소 활성화
# gpgcheck=1: GPG 키로 패키지 서명 검증
# gpgkey: GPG 키 URL
# exclude: 제외할 패키지 목록 (자동 업데이트 방지)
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# Kubernetes 도구를 설치합니다.
# kubelet: 각 노드에서 실행되는 에이전트, Pod를 관리합니다.
# kubeadm: Kubernetes 클러스터를 부트스트랩하는 도구입니다.
# kubectl: Kubernetes 클러스터와 상호작용하는 명령줄 도구입니다.
# --disableexcludes=kubernetes: exclude 목록을 무시하고 설치 (위에서 exclude했지만 설치해야 함)
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# kubelet 서비스를 부팅 시 자동 시작되도록 설정합니다.
# 주의: 아직 클러스터가 초기화되지 않았으므로 시작되지 않습니다.
systemctl enable kubelet

# ========================================
# 9. 추가 유틸리티 설치
# ========================================

echo "추가 유틸리티 설치 중..."

# bash-completion: bash 명령어 자동 완성 기능
# kubectl 명령어를 타이핑할 때 Tab 키로 자동 완성할 수 있게 합니다.
dnf install -y bash-completion

# root 사용자의 .bashrc 파일에 kubectl 자동 완성 설정을 추가합니다.
# source <(kubectl completion bash): kubectl의 bash 자동 완성 스크립트를 실행
# >> : 파일에 추가 (append)
echo 'source <(kubectl completion bash)' >> /root/.bashrc

# ========================================
# 10. 정리 작업
# ========================================

echo "정리 작업 중..."

# dnf 캐시를 정리합니다.
# dnf clean all: 모든 캐시 파일 삭제
dnf clean all

# dnf 캐시 디렉토리의 내용을 삭제합니다.
# /var/cache/dnf: dnf가 다운로드한 패키지 파일이 저장되는 위치
# rm -rf: 디렉토리와 내용을 재귀적으로 삭제
rm -rf /var/cache/dnf/*

# ========================================
# 완료 메시지
# ========================================

echo ""
echo "노드 준비가 성공적으로 완료되었습니다!"
echo ""
echo "설치된 버전:"
echo "- containerd: ${CONTAINERD_VERSION}"
echo "- runc: ${RUNC_VERSION}"
echo "- CNI 플러그인: ${CNI_PLUGINS_VERSION}"
echo ""
echo "다음 단계:"
echo "- 컨트롤 플레인 노드의 경우: kubeadm init으로 클러스터를 초기화하세요"
echo "- 워커 노드의 경우: kubeadm join으로 클러스터에 조인하세요"
echo "- containerd가 실행 중인지 확인: systemctl status containerd"
