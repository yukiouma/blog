---
title: 搭建HADOOP完全分布式
date: 2019-10-30 23:13:49
tags: 
- HADOOP
categories:
- 大数据离线开发
---

## 配置环境说明

   win10下使用vmware-workstation15 搭建 centOS 7 虚拟环境

   JDK版本：8u144

   Hadoop版本：2.8.4

   集群节点数：3
<!-- more -->    

## 前期准备


1. 在网络适配器中，将VMnet8的ip锁定为192.168.1.1

2. 在vmvare-workstation中的Edit -> Vitural Network Editor中将VMnet8的Subnet ip锁定为192.168.1.0

3. 使用vmvare新建一台虚拟机，配置为4G+30G，安装CentOS 7 (本次安装Minimal Version)

## 配置主节点

### 修改centOS中的配置文件


1. ```/etc/sysconfig/network-scripts/ifcfg-eno16777736```

```ifcfg-eno16777736
    BOOTPROTO="static"	# 将虚拟机的地址获取改为静态
    ONBOOT="yes"		# 
    IPADDR=192.168.1.111	# 前三段与VMnet8的ip中的第三段保持一致，第四段为自定义
    GATEWAY=192.168.1.2		# 与VMnet8的gateway保持一致
    NETMASK=255.255.255.0
    DNS1=8.8.8.8
```

2. ```/etc/resolv.conf```

```resolv.conf
    nameserver 8.8.8.8	# 与上面的DNS1保持一致
```

*  配置完后重启一下网络服务：```service network restart```
*  检查重启之后虚拟机地址是否生效：```ip addr```
*  检查网关是否能ping通：```ping 192.168.1.2```
*  检查虚拟机是否能连接互联网：```ping im.qq.com```

3. 关闭与禁用防火墙：

```shell
# 查看防火墙状态
systemctl status firewalld
# 关闭防火墙
systemctl stop firewalld
# 禁用防火墙
systemctl disable firewalld
```

关闭Selinux，将```/etc/selinux/config```该文件中的```SELINUX=enforcing```改为```SELINUX=disabled```

4. Hosts配置```/etc/hosts```

```shell
    127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
    ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
    192.168.1.111 bigdata111
    192.168.1.112 bigdata112
    192.168.1.113 bigdata113
```

* 查看本机主机名
```shell
hostname
```


5. 配置免密登录

```shell
ssh-keygen -t rsa		# 然后一直回车知道执行结束
ssh-copy-id bigdata111	# 提示是否继续连接选yes，提示输入用户密码
```

* 测试免密是否配置成功
```shell
ssh bigdata111
```

### 安装JDK

1. 使用```lrzsz```上传JDK压缩包

2. 解压至指定目录（ 本次目录为```/opt/module/``` ）
```
tar -zxvf jdk-8u144-linux-x64.tar.gz -C /opt/module/
```

3. 解压完成后，配置环境变量```vi /etc/profile```

```profile
export JAVA_HOME=/opt/module/jdk1.8.0_144
export PATH=$PATH:$JAVA_HOME/bin
```

4. 刷新配置文件：
```shell
source /etc/profile
```

5. 测试是否配置成功
```shell
java -version
```

### 安装HADOOP

1. 使用```lrzsz```上传Hadoop2.8.4的压缩包

2. 解压至指定目录（本次目录为```/opt/module/```）
```shell
tar -zxvf jdk-8u144-linux-x64.tar.gz -C /opt/module/
```

3. 配置环境变量```vi /etc/profile```

```shell
export HADOOP_HOME=/opt/module/hadoop-2.8.4
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
```

4. 刷新配置文件：
```shell
source /etc/profile
```

5. 测试是否配置成功
```shell
hadoop version
```

### 修改HADOOP配置文件

首先在```/opt/module/hadoop-2.8.4```下创建```data```和```logs```两个目录

1. ```core-site.xml```

```xml
<property>
    <name>fs.defaultFS</name>
    <value>hdfs://bigdata111:9000</value>
</property>

<property>
    <name>hadoop.tmp.dir</name>
    <value>/opt/module/hadoop-2.8.4/data/tmp</value>
</property>

```

2. ```hdfs-site.xml```

```xml
<!--数据冗余数-->
<property>
    <name>dfs.replication</name>
    <value>3</value>
</property>
<!--secondary的地址-->
<property>
    <name>dfs.namenode.secondary.http-address</name>
    <value>bigdata111:50090</value>
</property>
<!--关闭权限-->
<property>
    <name>dfs.permissions</name>
    <value>false</value>
</property>
```

3. ```yarn-site.xml```

```xml
<!-- reducer获取数据的方式 -->
<property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
</property>

<!-- 指定YARN的ResourceManager的地址 -->
<property>
    <name>yarn.resourcemanager.hostname</name>
    <value>bigdata111</value>
</property>

<!-- 日志聚集功能使能 -->
<property>
    <name>yarn.log-aggregation-enable</name>
    <value>true</value>
</property>
<!-- 日志保留时间设置7天(秒) -->
<property>
    <name>yarn.log-aggregation.retain-seconds</name>
    <value>604800</value>
</property>
```

4. ```mapred-site.xml```

首先```mv mapred-site.xml.template mapred-site.xml```

```xml
<!-- 指定mr运行在yarn上-->
<property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
</property>
<!--历史服务器的地址-->
<property>
    <name>mapreduce.jobhistory.address</name>
    <value>bigdata111:10020</value>
</property>
<!--历史服务器页面的地址-->
<property>
    <name>mapreduce.jobhistory.webapp.address</name>
    <value>bigdata111:19888</value>
</property>

```

5. ```hadoop-env.sh```, ```mapred-env.sh```, ```yarn-env.sh```三个脚本文件追加JDK安装路径的变量

```shell
export JAVA_HOME=/opt/module/jdk1.8.0_144

```

6. 配置```slaves```
   清空原内容后写入以下内容

```shell
bigdata111
bigdata112
bigdata113

```

7. 执行格式初始化
```shell
hdfs namenode -format
```

## 配置从节点

1. 关闭虚拟机```bigdata111```，克隆```bigdata111```两次，分别命名为```bigdata112```, ```bigdata113```

2. 修改```bigdata112```, ```bigdata113```的主机名

```shell
hostnamectl set-hostname bigdata112
hostnamectl set-hostname bigdata113
```

3. 修改```bigdata112```, ```bigdata113```的静态ip

```
vi /etc/sysconfig/network-scripts/ifcfg-eno16777736
IPADDR=192.168.1.112
```

重启服务 
```shell
service network restart
```

4. 配置免密登录

* 在搭建主节点的时候已经对进行过配置，此时我们仅需在在首次跳转的时候输入```yes```即可完成三台虚拟机的免密登陆配置

```shell
ssh bigdata112
Are you sure you want to continue connecting (yes/no)? yes
```

5. 清空三个节点中```/opt/module/hadoop-2.8.4```下的```data```和```logs```里面的所有内容
```shell
rm -rf data/* logs/*
```

6. 重新初始化主节点
```shell
hdfs namenode -format
```

## 启动HADOOP完全分布式

1. 在主节点的虚拟机中执行：

```shell
start-dfs.sh
start-yarn.sh
```

2. 在本地的浏览器中访问管理页面：```http://192.168.1.111:50070```

3. 修改```C:\Windows\System32\drivers\etc\hosts```

* 追加

```shell
192.168.1.111 bigdata111
192.168.1.112 bigdata112
192.168.1.113 bigdata113
```

之后便可使用```http://bigdata111:50070```访问管理页面

