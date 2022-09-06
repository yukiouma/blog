---
title: Nginx实现反向代理
date: 2021-05-23 18:10:44
tags: 
- Nginx
categories:
- Web开发
---

在虚拟机中部署Nginx，并使用Nginx为虚拟机中运行的项目分配反向代理的域名


## 背景说明

在windows宿主机中存在一台运行着CentOS7的虚拟机，ip为192.168.1.200

在虚拟机中存在一个web服务的项目，运行在虚拟机的端口8080上

希望在宿主机中能通过自定义的域名app01.com来访问该项目的接口服务

<!-- more -->

## 环境

* CentOS Linux release 7.7.1908 (Core)
* VMWare 15.5.0 build-14665864
* Windows 10, 64-bit  (Build 19042) 10.0.19042



## 步骤



### 修改windows宿主机中的hosts文件

hosts文件位于：`C:\Windows\System32\drivers\etc\hosts`

在hosts文件中添加自定义的域名-ip映射关系

```shell
192.168.1.200 app01.com
```



### 部署Nginx



#### 通过yum安装

```shell
yum install -y nginx
```



#### 查看版本

```shell
[root@playground nginx]# nginx -v
nginx version: nginx/1.16.1
```



### 配置反向代理



#### 添加自定义反向代理配置



通过`yum`进行安装时，`Nginx`的配置文件的路径会位于`/etc/nginx`下

配置文件是`/etc/nginx/nginx.conf`



我们在更改该文件之前先对其进行一下备份

```shell
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
```



然后添加我们自定义的服务配置

```nginx.conf.default
    server {
        listen       80;
        server_name  app01.com;

        location / {
            proxy_pass   http://127.0.0.1:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
```



### 启动Nginx

```shell
nginx
```

停止nginx

```shell
nginx -s stop
```

修改配置后重启Nginx

```shell
nginx -s reload
```

让Nginx开机自启动

```shell
systemctl enable nginx
```



自此，运行在虚拟机中端口为8080的项目已经成功被Nginx反向代理



## 测试

在windows宿主机的cmd中尝试请求

```shell
C:\Users\xxx>curl http://app01.com/api/organization
{"code":200,"data":[{"id":1,"name":"Oppose Militancy \u0026 Neutralize Invasion","alias":"O.M.N.I","pilot":[{"id":6,"name":"Stellar Loussier","organizationId":1,"organization":{"id":0,"name":"","alias":"","pilot":null},"Gundam":null}]},{"id":2,"name":"Zodiac Alliance of Freedom Treaty","alias":"Z.A.F.T","pilot":[{"id":1,"name":"Shinn Asuka","organizationId":2,"organization":{"id":0,"name":"","alias":"","pilot":null},"Gundam":null},{"id":4,"name":"Rau Le Crueset","organizationId":2,"organization":{"id":0,"name":"","alias":"","pilot":null},"Gundam":null},{"id":5,"name":"Rey Za Burrel","organizationId":2,"organization":{"id":0,"name":"","alias":"","pilot":null},"Gundam":null}]},{"id":3,"name":"Orb Union","alias":"O.R.B","pilot":[{"id":2,"name":"Kira Yamato","organizationId":3,"organization":{"id":0,"name":"","alias":"","pilot":null},"Gundam":null},{"id":3,"name":"Athrun Zala","organizationId":3,"organization":{"id":0,"name":"","alias":"","pilot":null},"Gundam":null},{"id":7,"name":"Mu La Flaga","organizationId":3,"organization":{"id":0,"name":"","alias":"","pilot":null},"Gundam":null}]}],"message":"Get organization successfully."}
```

发现能成功通过我们配置的域名app01.com来请求到数据