---
title: Nodejs安装
date: 2021-06-09 21:53:16
tags: 
- Nodejs
categories:
- Web开发
---

# Nodejs安装

## 环境与配置

* VMware® Workstation 15 Pro - 15.5.0 build-14665864
* 宿主机： Windows 10, 64-bit  (Build 19042) 10.0.19042
* CentOS Linux release 7.9.2009 (Core)



## 资源清单

* node-v12.16.1-linux-x64
* n 7.3.0

<!-- more -->


## 下载安装包

```shell
cd /opt/packages
wget https://npm.taobao.org/mirrors/node/v12.16.1/node-v12.16.1-linux-x64.tar.gz
```



## 解压与安装

```shell
cd /opt/modules
tar -C . -zxvf /opt/packages/node-v12.16.1-linux-x64.tar.gz
```



## 设置软连接

```shell
ln -s /opt/modules/node-v12.16.1-linux-x64/bin/node /usr/bin/node
ln -s /opt/modules/node-v12.16.1-linux-x64/bin/npm /usr/bin/npm
ln -s /opt/modules/node-v12.16.1-linux-x64/bin/npx /usr/bin/npx
```



## 安装node版本管理器n

```shell
npm i -g n
```

### 设置软连接

ps：不知道为啥全局安装之后n没有自己创建个软连接啥的....总觉得以前不用做这一步....

```shell
ln -s /opt/modules/node-v12.16.1-linux-x64/lib/node_modules/n/bin/n /usr/bin/n
```

### 设置N_PREFIX

```
vi /etc/profile
```

```vi
export N_PREFIX=/usr/local/bin/node
export PATH=$N_PREFIX/bin:$PATH
```

```shell
source /etc/profile
```



### 测试n是否安装成功

```shell
n --version
```

```
7.3.0
```



## 安装生产环境版本node

```shell
n 12.2.0
```

切换node

```shell
n
```

然后选择需要的版本，enter



## npm换源

```shell
npm config set registry https://registry.npm.taobao.org/
```

