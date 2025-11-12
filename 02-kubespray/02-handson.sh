#1 kubespray git clone
cd ~
git clone https://github.com/kubernetes-sigs/kubespray.git

#2 Python version
python3 --version

#3 Python 가상환경 생성
cd ~
VENVDIR=kubespray-venv
KUBESPRAYDIR='kubespray'
python3 -m venv $VENVDIR
source $VENVDIR/bin/activate
cd $KUBESPRAYDIR

pip install -r requirements.txt

#4 ansible version 확인
ansible --version

#5 kubespray inventory sample을 kubeclass로 복사
cd ~/kubespray/inventory/
cp -r sample kubeclass
cd kubeclass

#5 inventory.ini 파일과 custom.yml 파일을 현재 위치로 복사
cp ~/miribit_k8s_study/02-kubespray/inventory.ini .
cp ~/miribit_k8s_study/02-kubespray/custom.yml .

#6 inventory.ini 파일을 확인
cat inventory.ini

#7 inventory.ini 파일을 수정, 사용자 번호에 맞게 반드시 IP 주소와 호스트명을 수정하여 사용해야 합니다!
vim inventory.ini

#8 custom.yml 파일을 확인
cat custom.yml

#9 kubespray 디렉토리로 이동
cd ~/kubespray

#10 ansible playbook 실행
ansible-playbook -i ~/kubespray/inventory/kubeclass/inventory.ini cluster.yml -e @~/kubespray/inventory/kubeclass/custom.yml

#11 ssh-keygen 및 대상 노드에 ssh key 전송
ssh-keygen -t ed25519
ssh-copy-id root@192.168.104.81
ssh-copy-id root@192.168.104.82
ssh-copy-id root@192.168.104.83
ssh-copy-id root@192.168.104.84
ssh-copy-id root@192.168.104.85
ssh-copy-id root@192.168.104.86

#12 ansible playbook 실행
cd ~/kubespray
ansible-playbook -i ~/kubespray/inventory/kubeclass/inventory.ini cluster.yml -e @~/kubespray/inventory/kubeclass/custom.yml

#13 ssh로 접근하여 클러스터 상태를 확인
ssh root@192.168.104.81

#14 kubectl get nodes 명령어를 실행하여 클러스터 상태를 확인
kubectl get nodes

#15 kubeconfig 파일 확인
cat ~/.kube/config

