---
title: Docker Registry部署
date: 2022-05-30 21:07:37
tags: 
- Docker
categories:
- DevOps
---

## 介绍

[Docker Registry](https://docs.docker.com/registry/)是官方提供的工具，可以用于构建私有的镜像仓库。它通过暴露RESTFUL API来对存放在其中的镜像进行查看与管理。

<!-- more -->



## 环境

* OS

  ```bash
  $ lsb_release -a
  No LSB modules are available.
  Distributor ID: Ubuntu
  Description:    Ubuntu 20.04.4 LTS
  Release:        20.04
  Codename:       focal
  ```



* Docker

  ```bash
  $ docker version
  Client: Docker Engine - Community
   Version:           20.10.17
   API version:       1.41
   Go version:        go1.17.11
   Git commit:        100c701
   Built:             Mon Jun  6 23:02:57 2022
   OS/Arch:           linux/amd64
   Context:           default
   Experimental:      true
  
  Server: Docker Engine - Community
   Engine:
    Version:          20.10.17
    API version:      1.41 (minimum version 1.12)
    Go version:       go1.17.11
    Git commit:       a89b842
    Built:            Mon Jun  6 23:01:03 2022
    OS/Arch:          linux/amd64
    Experimental:     true
   containerd:
    Version:          1.6.6
    GitCommit:        10c12954828e7c7c9b6e0ea9b0c02b01407d3ae1
   runc:
    Version:          1.1.2
    GitCommit:        v1.1.2-0-ga916309
   docker-init:
    Version:          0.19.0
    GitCommit:        de40ad0
  ```
  
  

## 准备

1. 查看本机域名

   ```bash
   $ hostname
   playground
   
   $ ip addr | grep ens33
   2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
       inet 192.168.31.233/24 brd 192.168.31.255 scope global ens33
   ```

   可以看到本机的域名为playground， IP地址是192.168.31.233

2. 在其它设备上配置好对安装registry的设备的域名解析

   ```bash
   $ cat /etc/hosts
   127.0.0.1 localhost
   192.168.31.233 playground
   ```

   

## 部署

### 目录准备

创建一个用来配置docker registry的目录

```bash
$ cd <your dir>
$ mkdir -p certs
$ mkdir -p registry
```

`certs`目录用来存放证书和密钥

`registry`目录用来映射registry存放进行的目录，持久化镜像数据



### 配置证书

因为docker的通信默认使用https，因此我们需要为registry配置SSL/TLS证书。

由于是在本地使用的仓库，因此选择使用`openssl`自签发证书



在当前目录中的certs目录中生成私钥：

```bash
$ openssl genrsa -out $PWD/certs/server.key 4096
```

在当前目录中的certs目录中使用该私钥签发证书：

```bash
$ openssl req -new -x509 -days 3650 \
    -subj "/C=GB/L=China/O=grpc-server/CN=$(hostname)" \
    -addext "subjectAltName = DNS:$(hostname)" \
    -key $PWD/certs/server.key -out $PWD/certs/server.crt
```



### 运行docker registry

```bash
$ docker run -d \
  --restart=always \
  --name registry \
  -v "$(pwd)"/certs:/certs \
  -v "$(pwd)"/registry:/var/lib/registry \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/server.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/server.key \
  -p 5000:5000 \
  registry:2
cd023ac82d12ef37845ac741df7bafa57f9c48fed8223e032fd0a03259ef1157
```

命令解析：

* -v：将容器中的路径挂载到宿主机路径中

  这里映射了之前配置的`certs`和`registry`目录

* -e：设定环境变量

  `REGISTRY_HTTP_ADDR`：项目监听的地址

  `REGISTRY_HTTP_TLS_CERTIFICATE`：证书在容器中的地址

  `REGISTRY_HTTP_TLS_KEY`：密钥在容器中的地址

* -p：运行端口

  

### 在本机和其它设备安装上自签发证书

```bash
$ cp $PWD/certs/server.crt /usr/local/share/ca-certificates/
$ sudo update-ca-certificates
```

尝试能否访问registry

```bash
$ curl https://playground:5000/v2/_catalog
{"repositories":[]}
```

成功返回空仓库列表表示配置成功


### 总结

最后我们可以将上述的操作封装成一个shell脚本，如下：
```sh
#!/usr/bin/bash

# prepare folder
mkdir -p certs
mkdir -p registry

# generate private key and certificate
openssl genrsa -out $PWD/certs/server.key 4096
openssl req -new -x509 -days 3650 \
    -subj "/C=GB/L=China/O=grpc-server/CN=$(hostname)" \
    -addext "subjectAltName = DNS:$(hostname)" \
    -key $PWD/certs/server.key -out $PWD/certs/server.crt

# start registry
docker run -d \
    --restart=always \
    --name registry \
    -v "$(pwd)"/certs:/certs \
    -v "$(pwd)"/registry:/var/lib/registry \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/server.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/server.key \
    -p 5000:5000 \
    registry:2

# install certificate to device
cp $PWD/certs/server.crt /usr/local/share/ca-certificates/
update-ca-certificates
```

以后安装的时候执行这个脚本即可

## 常用操作

### 查看私有仓库中的镜像列表

```bash
$ curl https://playground:5000/v2/_catalog
{"repositories":[]}
```



### 本地镜像推送至registry

先为本地镜像打上标签

```bash
$ docker tag nginx:latest playground:5000/nginx:v1
```



推送至私有仓库

```bash
$ docker push playground:5000/nginx:v1
```



再次查看私有仓库镜像列表

```bash
$ curl https://playground:5000/v2/_catalog
{"repositories":["nginx"]}
```

此时列表存在刚上传的镜像了



### 从registry拉取镜像

由于我们刚刚上传到registry中的Nginx是没有任何改动的，为了体现拉取效果我们先要把原本的和tag后的Nginx镜像均移除

```bash
$ docker rmi playground:5000/nginx:v1
$ docker rmi nginx
```

从registry拉取刚刚上传的镜像

```bash
$ docker pull playgrouond:5000/nginx:v1
v1: Pulling from nginx
1efc276f4ff9: Pull complete 
baf2da91597d: Pull complete 
05396a986fd3: Pull complete 
6a17c8e7063d: Pull complete 
27e0d286aeab: Pull complete 
b1349eea8fc5: Pull complete 
```

可以看到拉取成功



### 查看某镜像的tag列表

```bash
$ curl https://host:port/v2/<image_name>/tags/list
```

如：

```bash
$ curl https://playground:5000/v2/nginx/tags/list
{"name":"nginx","tags":["v1"]}
```

可以看到当前在registry中的nginx仅有我们刚刚上传的版本v1



### 查看镜像某个版本的详情

```bash
$ curl https://host:port/v2/<image_name>/manifests/<tag_name>
```

如：

```bash
$ curl https://playgrouond:5000/v2/nginx/manifests/v1
{
   "schemaVersion": 1,
   "name": "nginx",
   "tag": "v1",
   "architecture": "amd64",
   "fsLayers": [
      {
         "blobSum": "sha256:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4"
      },
      {
         "blobSum": "sha256:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4"
      },
      {
         "blobSum": "sha256:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4"
      },
      {
         "blobSum": "sha256:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4"
      },
      {
         "blobSum": "sha256:b1349eea8fc5b5eebb633c2cd79fc24a915fcb00279de24684bb07e349e8eab3"
      },
      {
         "blobSum": "sha256:27e0d286aeab484653fdf0f736d5f7a2fbcc572e387ec8a1d6ccf0e74b6bfefc"
      },
      {
         "blobSum": "sha256:6a17c8e7063d97ef72e89f7d4673935ff9a2b7c179bea1726852399219118f65"
      },
      {
         "blobSum": "sha256:05396a986fd3f3739cc890e30a2ed78e377c6a2b24d9f0ebe99ff3349aedc603"
      },
      {
         "blobSum": "sha256:baf2da91597d101646b307b706d06b048862192b127f74b1079d374d902e32f4"
      },
      {
         "blobSum": "sha256:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4"
      },
      {
         "blobSum": "sha256:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4"
      },
      {
         "blobSum": "sha256:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4"
      },
      {
         "blobSum": "sha256:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4"
      },
      {
         "blobSum": "sha256:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4"
      },
      {
         "blobSum": "sha256:1efc276f4ff952c055dea726cfc96ec6a4fdb8b62d9eed816bd2b788f2860ad7"
      }
   ],
   "history": [
      {
         "v1Compatibility": "{\"architecture\":\"amd64\",\"config\":{\"Hostname\":\"\",\"Domainname\":\"\",\"User\":\"\",\"AttachStdin\":false,\"AttachStdout\":false,\"AttachStderr\":false,\"ExposedPorts\":{\"80/tcp\":{}},\"Tty\":false,\"OpenStdin\":false,\"StdinOnce\":false,\"Env\":[\"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\",\"NGINX_VERSION=1.23.1\",\"NJS_VERSION=0.7.6\",\"PKG_RELEASE=1~bullseye\"],\"Cmd\":[\"nginx\",\"-g\",\"daemon off;\"],\"Image\":\"sha256:0417134432daa8913f92f7bf71641a8fa7ab3405c91b717dde22c855e71eef4d\",\"Volumes\":null,\"WorkingDir\":\"\",\"Entrypoint\":[\"/docker-entrypoint.sh\"],\"OnBuild\":null,\"Labels\":{\"maintainer\":\"NGINX Docker Maintainers \\u003cdocker-maint@nginx.com\\u003e\"},\"StopSignal\":\"SIGQUIT\"},\"container\":\"5f19bc2cd794cd60ec845cbed7a60c85003dc56f26ee807f9eea2480bc465b76\",\"container_config\":{\"Hostname\":\"5f19bc2cd794\",\"Domainname\":\"\",\"User\":\"\",\"AttachStdin\":false,\"AttachStdout\":false,\"AttachStderr\":false,\"ExposedPorts\":{\"80/tcp\":{}},\"Tty\":false,\"OpenStdin\":false,\"StdinOnce\":false,\"Env\":[\"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\",\"NGINX_VERSION=1.23.1\",\"NJS_VERSION=0.7.6\",\"PKG_RELEASE=1~bullseye\"],\"Cmd\":[\"/bin/sh\",\"-c\",\"#(nop) \",\"CMD [\\\"nginx\\\" \\\"-g\\\" \\\"daemon off;\\\"]\"],\"Image\":\"sha256:0417134432daa8913f92f7bf71641a8fa7ab3405c91b717dde22c855e71eef4d\",\"Volumes\":null,\"WorkingDir\":\"\",\"Entrypoint\":[\"/docker-entrypoint.sh\"],\"OnBuild\":null,\"Labels\":{\"maintainer\":\"NGINX Docker Maintainers \\u003cdocker-maint@nginx.com\\u003e\"},\"StopSignal\":\"SIGQUIT\"},\"created\":\"2022-08-02T05:17:19.274343015Z\",\"docker_version\":\"20.10.12\",\"id\":\"7c5cdba2be2c5c3bdc971384d8b59252de4872d6d6bb58fce757f7f91c8e814a\",\"os\":\"linux\",\"parent\":\"8ca7e4f3d4f29f3b6f6faff7967f155deaec0b0cbad1d803a0821e38a4c9a002\",\"throwaway\":true}"
      },
      {
         "v1Compatibility": "{\"id\":\"8ca7e4f3d4f29f3b6f6faff7967f155deaec0b0cbad1d803a0821e38a4c9a002\",\"parent\":\"fe24cb7d5bfcb7abdb8e9d6d3a968c39d40a9a58d7d6fd6fd93ff59ba5297597\",\"created\":\"2022-08-02T05:17:19.181030991Z\",\"container_config\":{\"Cmd\":[\"/bin/sh -c #(nop)  STOPSIGNAL SIGQUIT\"]},\"throwaway\":true}"
      },
      {
         "v1Compatibility": "{\"id\":\"fe24cb7d5bfcb7abdb8e9d6d3a968c39d40a9a58d7d6fd6fd93ff59ba5297597\",\"parent\":\"fb2f20a92a2fc4111b7fa3bda0f2e227eb223be9e019d4350fb511f28226824b\",\"created\":\"2022-08-02T05:17:19.086729123Z\",\"container_config\":{\"Cmd\":[\"/bin/sh -c #(nop)  EXPOSE 80\"]},\"throwaway\":true}"
      },
      {
         "v1Compatibility": "{\"id\":\"fb2f20a92a2fc4111b7fa3bda0f2e227eb223be9e019d4350fb511f28226824b\",\"parent\":\"02ed2b7141b9f0835fb4efa4ccfd4b6eec9b41f2d4d85585d063068d8e98aee8\",\"created\":\"2022-08-02T05:17:18.99389332Z\",\"container_config\":{\"Cmd\":[\"/bin/sh -c #(nop)  ENTRYPOINT [\\\"/docker-entrypoint.sh\\\"]\"]},\"throwaway\":true}"
      },
      {
         "v1Compatibility": "{\"id\":\"02ed2b7141b9f0835fb4efa4ccfd4b6eec9b41f2d4d85585d063068d8e98aee8\",\"parent\":\"ceeb2e38c614ca2e627cab7a7fcc566ee8df510f6c191f2acc05a5d8cfaa603e\",\"created\":\"2022-08-02T05:17:18.902903333Z\",\"container_config\":{\"Cmd\":[\"/bin/sh -c #(nop) COPY file:09a214a3e07c919af2fb2d7c749ccbc446b8c10eb217366e5a65640ee9edcc25 in /docker-entrypoint.d \"]}}"
      },
      {
         "v1Compatibility": "{\"id\":\"ceeb2e38c614ca2e627cab7a7fcc566ee8df510f6c191f2acc05a5d8cfaa603e\",\"parent\":\"c48f34848f468e802779942c8e466812b1707e45f2b40b2e4218780f9de5e89e\",\"created\":\"2022-08-02T05:17:18.793448025Z\",\"container_config\":{\"Cmd\":[\"/bin/sh -c #(nop) COPY file:0fd5fca330dcd6a7de297435e32af634f29f7132ed0550d342cad9fd20158258 in /docker-entrypoint.d \"]}}"
      },
      {
         "v1Compatibility": "{\"id\":\"c48f34848f468e802779942c8e466812b1707e45f2b40b2e4218780f9de5e89e\",\"parent\":\"2fdecd1475853cb1580d27ea00d3d3bda678d6b42113458647aed44ba65813f2\",\"created\":\"2022-08-02T05:17:18.687477159Z\",\"container_config\":{\"Cmd\":[\"/bin/sh -c #(nop) COPY file:0b866ff3fc1ef5b03c4e6c8c513ae014f691fb05d530257dfffd07035c1b75da in /docker-entrypoint.d \"]}}"
      },
      {
         "v1Compatibility": "{\"id\":\"2fdecd1475853cb1580d27ea00d3d3bda678d6b42113458647aed44ba65813f2\",\"parent\":\"c3c349bd8afc6759f2f317980c4556c63c2293f015cdbc2edf999f9a6b6fc700\",\"created\":\"2022-08-02T05:17:18.579257834Z\",\"container_config\":{\"Cmd\":[\"/bin/sh -c #(nop) COPY file:65504f71f5855ca017fb64d502ce873a31b2e0decd75297a8fb0a287f97acf92 in / \"]}}"
      },
      {
         "v1Compatibility": "{\"id\":\"c3c349bd8afc6759f2f317980c4556c63c2293f015cdbc2edf999f9a6b6fc700\",\"parent\":\"3fd6cfd0997f003bf2bd7303d989d421f7467e0c1efbde37ae85096a96fe20a1\",\"created\":\"2022-08-02T05:17:18.33359297Z\",\"container_config\":{\"Cmd\":[\"/bin/sh -c set -x     \\u0026\\u0026 addgroup --system --gid 101 nginx     \\u0026\\u0026 adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos \\\"nginx user\\\" --shell /bin/false --uid 101 nginx     \\u0026\\u0026 apt-get update     \\u0026\\u0026 apt-get install --no-install-recommends --no-install-suggests -y gnupg1 ca-certificates     \\u0026\\u0026     NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62;     found='';     for server in         hkp://keyserver.ubuntu.com:80         pgp.mit.edu     ; do         echo \\\"Fetching GPG key $NGINX_GPGKEY from $server\\\";         apt-key adv --keyserver \\\"$server\\\" --keyserver-options timeout=10 --recv-keys \\\"$NGINX_GPGKEY\\\" \\u0026\\u0026 found=yes \\u0026\\u0026 break;     done;     test -z \\\"$found\\\" \\u0026\\u0026 echo \\u003e\\u00262 \\\"error: failed to fetch GPG key $NGINX_GPGKEY\\\" \\u0026\\u0026 exit 1;     apt-get remove --purge --auto-remove -y gnupg1 \\u0026\\u0026 rm -rf /var/lib/apt/lists/*     \\u0026\\u0026 dpkgArch=\\\"$(dpkg --print-architecture)\\\"     \\u0026\\u0026 nginxPackages=\\\"         nginx=${NGINX_VERSION}-${PKG_RELEASE}         nginx-module-xslt=${NGINX_VERSION}-${PKG_RELEASE}         nginx-module-geoip=${NGINX_VERSION}-${PKG_RELEASE}         nginx-module-image-filter=${NGINX_VERSION}-${PKG_RELEASE}         nginx-module-njs=${NGINX_VERSION}+${NJS_VERSION}-${PKG_RELEASE}     \\\"     \\u0026\\u0026 case \\\"$dpkgArch\\\" in         amd64|arm64)             echo \\\"deb https://nginx.org/packages/mainline/debian/ bullseye nginx\\\" \\u003e\\u003e /etc/apt/sources.list.d/nginx.list             \\u0026\\u0026 apt-get update             ;;         *)             echo \\\"deb-src https://nginx.org/packages/mainline/debian/ bullseye nginx\\\" \\u003e\\u003e /etc/apt/sources.list.d/nginx.list                         \\u0026\\u0026 tempDir=\\\"$(mktemp -d)\\\"             \\u0026\\u0026 chmod 777 \\\"$tempDir\\\"                         \\u0026\\u0026 savedAptMark=\\\"$(apt-mark showmanual)\\\"                         \\u0026\\u0026 apt-get update             \\u0026\\u0026 apt-get build-dep -y $nginxPackages             \\u0026\\u0026 (                 cd \\\"$tempDir\\\"                 \\u0026\\u0026 DEB_BUILD_OPTIONS=\\\"nocheck parallel=$(nproc)\\\"                     apt-get source --compile $nginxPackages             )                         \\u0026\\u0026 apt-mark showmanual | xargs apt-mark auto \\u003e /dev/null             \\u0026\\u0026 { [ -z \\\"$savedAptMark\\\" ] || apt-mark manual $savedAptMark; }                         \\u0026\\u0026 ls -lAFh \\\"$tempDir\\\"             \\u0026\\u0026 ( cd \\\"$tempDir\\\" \\u0026\\u0026 dpkg-scanpackages . \\u003e Packages )             \\u0026\\u0026 grep '^Package: ' \\\"$tempDir/Packages\\\"             \\u0026\\u0026 echo \\\"deb [ trusted=yes ] file://$tempDir ./\\\" \\u003e /etc/apt/sources.list.d/temp.list             \\u0026\\u0026 apt-get -o Acquire::GzipIndexes=false update             ;;     esac         \\u0026\\u0026 apt-get install --no-install-recommends --no-install-suggests -y                         $nginxPackages                         gettext-base                         curl     \\u0026\\u0026 apt-get remove --purge --auto-remove -y \\u0026\\u0026 rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx.list         \\u0026\\u0026 if [ -n \\\"$tempDir\\\" ]; then         apt-get purge -y --auto-remove         \\u0026\\u0026 rm -rf \\\"$tempDir\\\" /etc/apt/sources.list.d/temp.list;     fi     \\u0026\\u0026 ln -sf /dev/stdout /var/log/nginx/access.log     \\u0026\\u0026 ln -sf /dev/stderr /var/log/nginx/error.log     \\u0026\\u0026 mkdir /docker-entrypoint.d\"]}}"
      },
      {
         "v1Compatibility": "{\"id\":\"3fd6cfd0997f003bf2bd7303d989d421f7467e0c1efbde37ae85096a96fe20a1\",\"parent\":\"dcc8c26ddc8409ff37d3895ce5adf5492ce187ea09b4751ec501584e31abf03a\",\"created\":\"2022-08-02T05:17:00.535362459Z\",\"container_config\":{\"Cmd\":[\"/bin/sh -c #(nop)  ENV PKG_RELEASE=1~bullseye\"]},\"throwaway\":true}"
      },
      {
         "v1Compatibility": "{\"id\":\"dcc8c26ddc8409ff37d3895ce5adf5492ce187ea09b4751ec501584e31abf03a\",\"parent\":\"4df58b427a2c2c53919701c0405aaa071185f1ffdbb014daae09f09a6f56360c\",\"created\":\"2022-08-02T05:17:00.433340106Z\",\"container_config\":{\"Cmd\":[\"/bin/sh -c #(nop)  ENV NJS_VERSION=0.7.6\"]},\"throwaway\":true}"
      },
      {
         "v1Compatibility": "{\"id\":\"4df58b427a2c2c53919701c0405aaa071185f1ffdbb014daae09f09a6f56360c\",\"parent\":\"2ed7164a1633ba5cfc8e0ce25262eeb1d7a99f38d3414aa87630516e0301e9b3\",\"created\":\"2022-08-02T05:17:00.343304803Z\",\"container_config\":{\"Cmd\":[\"/bin/sh -c #(nop)  ENV NGINX_VERSION=1.23.1\"]},\"throwaway\":true}"
      },
      {
         "v1Compatibility": "{\"id\":\"2ed7164a1633ba5cfc8e0ce25262eeb1d7a99f38d3414aa87630516e0301e9b3\",\"parent\":\"19bb5024a04e90058473c3a95454bf71af1656ba7e37dd864e403d7fb2d249ac\",\"created\":\"2022-08-02T05:17:00.247750692Z\",\"container_config\":{\"Cmd\":[\"/bin/sh -c #(nop)  LABEL maintainer=NGINX Docker Maintainers \\u003cdocker-maint@nginx.com\\u003e\"]},\"throwaway\":true}"
      },
      {
         "v1Compatibility": "{\"id\":\"19bb5024a04e90058473c3a95454bf71af1656ba7e37dd864e403d7fb2d249ac\",\"parent\":\"7bd28761fdea7d2851f6653f32245cfbf7d7f0f927f3b32668239cb49d865ee1\",\"created\":\"2022-08-02T01:20:05.41127808Z\",\"container_config\":{\"Cmd\":[\"/bin/sh -c #(nop)  CMD [\\\"bash\\\"]\"]},\"throwaway\":true}"
      },
      {
         "v1Compatibility": "{\"id\":\"7bd28761fdea7d2851f6653f32245cfbf7d7f0f927f3b32668239cb49d865ee1\",\"created\":\"2022-08-02T01:20:04.9776465Z\",\"container_config\":{\"Cmd\":[\"/bin/sh -c #(nop) ADD file:0eae0dca665c7044bf242cb1fc92cb8ea744f5af2dd376a558c90bc47349aefe in / \"]}}"
      }
   ],
   "signatures": [
      {
         "header": {
            "jwk": {
               "crv": "P-256",
               "kid": "V6GK:RYTU:FNW5:UNFW:5VU7:2STC:7EVV:OU4V:GCNH:4G25:B4DC:6LPO",
               "kty": "EC",
               "x": "02YpQs5EF9DzBwcVghEHsuYpr28-i6RpGaG3cnrELpc",
               "y": "4gsUgQU-sr7rkFLMLwttkzjm0x5eiHet9qvzXyyD_Dk"
            },
            "alg": "ES256"
         },
         "signature": "Q6IIOS3BHeNPo-T8vBWa36RshFtj8ccIbc0zkbePBWWxUezkD1UH0D35mm42-I0XhFNej-_O9UbfTs_lkggtyw",
         "protected": "eyJmb3JtYXRMZW5ndGgiOjEyNTM1LCJmb3JtYXRUYWlsIjoiQ24wIiwidGltZSI6IjIwMjItMTAtMjZUMDg6MzQ6NDJaIn0"
      }
   ]
}
```



### 其它web api参考文档

[Dokcer Registry](https://docs.docker.com/registry/)