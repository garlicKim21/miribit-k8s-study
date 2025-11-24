#1 multi-container-pod.yaml 파일을 확인합니다.
cat multi-container-pod.yaml

#2 multi-container-pod.yaml 파일을 실행합니다.
kubectl apply -f multi-container-pod.yaml

#3 multi-container-pod.yaml 파일을 확인합니다.
kubectl get pods

#4 multi-container-pod.yaml 파일을 확인합니다.
kubectl describe pod multi-container-pod

#5 pod내 nginx container 접속
kubectl exec -it multi-container-pod -c nginx-container -- bash

#6 pod에서 localhost:80 호출
curl localhost:80

#7 pod에서 localhost:5678 호출
curl localhost:5678

#8 밖으로 빠져나옵니다.
exit

#9 clusterip.yaml 파일을 확인합니다.
cat clusterip.yaml

#10 clusterip.yaml 파일을 실행합니다.
kubectl apply -f clusterip.yaml

#11 clusterip.yaml 파일을 확인합니다.
kubectl get services

#12 clusterip 서비스 상세 정보를 확인합니다.
kubectl describe service multi-cont-pod

#13 clusterip의 서비스 IP와 80번 포트를 호출합니다.
CLUSTER_IP=$(kubectl get svc multi-cont-pod -o jsonpath='{.spec.clusterIP}{"\n"}')
curl http://$CLUSTER_IP:80

#14 clusterip의 서비스 IP와 5678번 포트를 호출합니다.
CLUSTER_IP=$(kubectl get svc multi-cont-pod -o jsonpath='{.spec.clusterIP}{"\n"}')
curl http://$CLUSTER_IP:5678

#15 nodeport.yaml 파일을 확인합니다.
cat nodeport.yaml

#16 nodeport.yaml 파일을 실행합니다.
kubectl apply -f nodeport.yaml

#17 nodeport.yaml 파일을 확인합니다.
kubectl get services

#18 nodeport 서비스 상세 정보를 확인합니다.
kubectl describe service multi-cont-pod-nodeport

#19 nodeport의 8080번 포트를 호출합니다.
curl 192.168.104.81:30080

#20 nodeport의 8765번 포트를 호출합니다.
curl 192.168.104.81:30765