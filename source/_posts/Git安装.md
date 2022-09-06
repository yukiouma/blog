---
title: Git安装
date: 2021-06-07 14:42:43
tags: 
- git
categories:
- 其它
---

# Git安装



## 环境

* VMware® Workstation 15 Pro - 15.5.0 build-14665864
* 宿主机： Windows 10, 64-bit  (Build 19042) 10.0.19042
* CentOS Linux release 7.9.2009 (Core)

<!-- more -->

## 步骤


### 安装wget

```shell
yum install -y wget
```



### 安装编译组件

```shell
yum install -y curl-devel
yum install -y gcc-c++
yum install -y zlib-devel perl-ExtUtils-MakeMaker
```



### 下载解压git

```shell
cd /opt/packages
wget https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.9.0.tar.gz
cd /opt/modules
tar -C . -zxvf ../packages/git-2.9.0.tar.gz
```



### 编译部署

```shell
cd /opt/modules/git-2.9.0/
./configure --prefix=/usr/local
make
make install
```



### 配置环境变量

```shell
vi /etc/profile
```

```vi
export PATH=$PATH:/usr/local/bin
```

```shell
source /etc/profile
```



### 测试

```shell
git --version
```

```shell
git version 2.9.0
```




