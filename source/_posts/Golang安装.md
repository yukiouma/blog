---
title: Golang安装
date: 2021-05-23 18:22:21
tags: 
- Golang
categories:
- Web开发
---



## 说明

在CentOS7中部署Golang开发环境

**注意**: Go的安装路径一定要在/usr/local，否在在vsc上安装Go插件时会导致找不到编译器。。。

<!-- more -->

## 环境

* CentOS Linux release 7.7.1908 (Core)
* go version go1.16.3 linux/amd64



## 安装包下载

https://golang.google.cn/dl/



## 安装

```shell
cd /usr/local/

sudo tar -C . -zxvf /mnt/d/SoftwarePackages/Golang/go1.16.3.linux-amd64.tar.gz
```



## 配置

配置环境变量

```shell
sudo vi ~/.bashrc
```

```vi
export PATH=$PATH:/home/yuki/packages/go/bin
```

```shell
source ~/.bashrc
```



## 检查是否安装成功

```shell
go version
```

```shell
go version go1.16.3 linux/amd64
```



## 更改配置

主要是开启Go Module以及将镜像设置为优先从阿里云或者微软源下载

```shell
go env -w GO111MODULE=on
go env -w GOPROXY=https://mirrors.aliyun.com/goproxy,https://goproxy.io,direct
```





## Vscode插件

Go



## 调试

reference: https://github.com/golang/vscode-go/blob/master/docs/debugging.md#installation

use Delve



in vscode:

* Ctrl+Shift+P
* select [`Go: Install/Update Tools`](https://github.com/golang/vscode-go/blob/master/docs/settings.md#go-installupdate-tools), and select [`dlv`](https://github.com/golang/vscode-go/blob/master/docs/tools.md#dlv).
* install

