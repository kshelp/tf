# Web(NGINX) 이미지 — 학습자료 5.4.8 1 (NGINX 설치)
# NGINX 설정(default.conf)은 이미지에 넣지 않고 gitops/의 ConfigMap으로 마운트한다.
# 그래서 설정만 바꿀 때는 이미지를 다시 빌드하지 않고 gitops/default.conf를 고쳐 push하면 된다.
#
# 빌드·push: scripts/push-images.sh web  (EKS 노드가 x86_64이므로 linux/amd64로 빌드한다)
FROM nginx:1.28
