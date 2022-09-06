---
title: 使用docker快速安装RabbitMQ
date: 2021-10-17 11:01:43
tags: 
- RabbitMQ
categories:
- DevOps
---



## 环境与配置

* VMware® Workstation 15 Pro - 15.5.0 build-14665864
* 宿主机： Windows 10, 64-bit  (Build 19042) 10.0.19042
* CentOS Linux release 7.9.2009 (Core)



## 资源清单

* docker 20.10.1
* RabbitMQ镜像: docker.io/rabbitmq:3.8-management

<!-- more -->

## 步骤



### 拉取镜像

```bash
docker pull docker.io/rabbitmq:3.8-management
```

要注意要拉取镜像名称带有management的镜像。默认的镜像是不带有web管理界面的



### 启动容器

查看镜像的ID

```bash
[root@playground ~]# docker images | grep mq
rabbitmq                3.8-management   d589227b9b99   23 hours ago    250MB
```

由上面的结果可知在本机的rabbitmq镜像id为`d589227b9b99`



启动容器

```bash
docker run --name rabbitmq -d -p 15672:15672 -p 5672:5672 d589227b9b99
```

命令解析：

`--name`: 指定容器名称

`-d`: 进程守护模式运行

`-p 15672:15672`: 15672端口为web服务客户端的端口，将容器的该端口映射到宿主机的相同的端口号中

`-p 5672:5672`:  5672端口为中间件服务端口，将容器的该端口映射到宿主机的相同的端口号中



查看容器是否正常运行

```bash
[root@playground ~]# docker ps | grep mq
3c13d0f36e9b   d589227b9b99                   "docker-entrypoint.s…"   25 minutes ago   Up 25 minutes      4369/tcp, 5671/tcp, 0.0.0.0:5672->5672/tcp, 15671/tcp, 15691-15692/tcp, 25672/tcp, 0.0.0.0:15672->15672/tcp   rabbitmq

```



### web服务访问

浏览器输入`<主机ip>:15672`

默认创建的账号密码均为guest

![1634441126.jpg](1634441126.jpg)

如果能正常登录并看到该页面，表示web服务正常运行



### 创建用户

 默认的`guest` 账户有访问限制，默认只能通过本地网络(如 localhost) 访问，远程网络访问受限，我们添加一个root用户以满足远程网络访问的需求



进入容器内

```bash
docker exec -it 3c13d0f36e9b bin/bash
```

创建用户

```bash
root@3c13d0f36e9b:/# rabbitmqctl add_user root 000000 
Adding user "root" ...
```

赋予root所有权限

```bash
root@3c13d0f36e9b:/# rabbitmqctl set_permissions -p / root ".*" ".*" ".*"
Setting permissions for user "root" in vhost "/" ...
```

 赋予root用户administrator角色 

```bash
root@3c13d0f36e9b:/# rabbitmqctl set_user_tags root administrator
Setting tags for user "root" to [adminstrator] ...
```

查看用户是否被成功建立

```bash
root@3c13d0f36e9b:/# rabbitmqctl list_users
Listing users ...
user	tags
guest	[administrator]
root	[administrator]
```

执行`exit`退出容器



回到web页面，测试root用户是否能成功登录


## 参考文章
[docker安装RabbitMq](https://juejin.cn/post/6844903970545090574)