# WAS(Flask) 이미지 — 학습자료 5.4.7 1~5 (Flask 설치·앱 내려받기)를 이미지 빌드 단계로 옮긴 것
# 예전에는 파드가 뜰 때마다 pip install·git clone을 했다(1~2분). 이제 이미지에 미리 넣어 두므로 바로 시작한다.
#
# 빌드·push: scripts/push-images.sh was  (EKS 노드가 x86_64이므로 linux/amd64로 빌드한다)

# ---------- 1단계: 빌드 (컴파일러·MySQL 헤더가 있는 전체 이미지) ----------
FROM python:3.12-bookworm AS build

# mysqlclient는 C 확장이라 빌드 도구가 필요하다. 모든 패키지를 wheel로 만들어 두고 2단계에서 설치한다.
RUN pip wheel --no-cache-dir --wheel-dir /wheels \
      Flask Flask-WTF Flask-Login Flask-MySQLdb mysqlclient Flask-Session Werkzeug redis

# 앱 소스 (커밋을 고정해 같은 태그는 항상 같은 내용이 되게 한다)
ARG APP_REPO=https://github.com/frodo5020/mywas2.git
ARG APP_COMMIT=0ead62075b948048420eb861d741b389ad040ef9
RUN git clone "$APP_REPO" /src \
 && git -C /src checkout "$APP_COMMIT" \
 && rm -rf /src/.git

# ---------- 2단계: 실행 (slim 이미지 + MySQL 클라이언트 런타임 라이브러리만) ----------
FROM python:3.12-slim-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends libmariadb3 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /wheels /wheels
RUN pip install --no-cache-dir --root-user-action=ignore --no-index /wheels/*.whl \
 && rm -rf /wheels

COPY --from=build /src /app/mywas2
WORKDIR /app/mywas2

EXPOSE 5000
CMD ["python3", "app.py"]
