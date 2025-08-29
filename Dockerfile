#ARG IMAGE=irepo.intersystems.com/intersystems/iris:2022.1.3.670.1
ARG IMAGE=containers.intersystems.com/intersystems/iris-community:2025.1
FROM $IMAGE

USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/src
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/src
USER ${ISC_PACKAGE_MGRUSER}

# ビルド中に実行したいスクリプトがあるファイルをコンテナにコピーしています
COPY iris.script .
COPY src .
COPY requirements.txt .
#COPY iris.key ${ISC_PACKAGE_INSTALLDIR}/mgr/iris.key

# IRISを開始し、IRISにログインし、iris.scriptに記載のコマンドを実行しています
RUN iris start IRIS \
    && pip install -r requirements.txt --break-system-packages \
    && iris session IRIS < iris.script \
    && iris stop IRIS quietly 