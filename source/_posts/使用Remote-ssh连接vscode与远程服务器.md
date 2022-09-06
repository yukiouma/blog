---
title: 使用Remote-ssh连接vscode与远程服务器
date: 2020-07-14 22:42:40
tags: 
- VS Code
categories:
- 其它
---



## 环境配置

* 宿主机：Windows10

* 服务器：CentOS 7
* VsCode：1.47.0
* Remote-ssh：0.51.0

<!-- more -->

## 连接步骤

1. 在宿主机上，安装OpenSSH

2. Git bash中运行

   ```shell
   ssh-keygen -t rsa -b 4096 - "xxxx" # 请将xxxx替换成自己定义的内容，一般习惯为自己邮箱
   ```

   之后可以一路回车确定即可，完成后在宿主机的目录```C:\Users\username\.ssh```下会看到生成了```id_rsa```与```id_rsa.pub```两个文件

3. 将```id_rsa.pub```上传至服务器的```~/.ssh/```目录下，并更名为```authorized_keys```

4. 在宿主机的```C:\Users\username\.ssh```中配置文件```config```，内容如下

   ```
   Host myServer	# 服务器名
   	HostName 192.168.1.233 #服务器ip
   	User root	# 登录用户名
   
   ```

5. 在VsCode中安装插件Remote-ssh

6. 在VsCode的左侧图标中找到Remote Explore，点击后会看到我们刚刚在在文件```config```中配置的服务器名，右键选择连接至该服务器，在左下角看到SSH: <服务器名称>即表示连接成功



## 遇到的问题

1. 今天不知道为啥突然打开虚拟机之后VsCode突然远程连接不上了，但是Xshell是能正常连接的，然后具体报错的内容为：

   ```
   failed to create hard link '/home/*/.vscode-server/bin/*/*' file exists
   ```

   搜索了一下，发现以下方法可以解决：

   连接上服务器后，把服务器上的```/root/.vscode-server/bin/```的日期最新的文件夹中的名字带有```vscode-remote-lock.root```的两个文件删除，重新使用VsCode连接后成功。