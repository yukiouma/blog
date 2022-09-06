---
title: Docker部署Kafka集群
date: 2022-05-24 21:22:51
tags: 
- MQ
categories:
- Web开发
---



## 安装docker-compose

<!-- more -->  

下载docker-compose

```bash
curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
```



设置docker-compose为可执行文件

```bash
chmod +x /usr/local/bin/docker-compose
```



## 准备工作



### docker-compose.yaml

```yaml
version: '3.3'
services:
  zookeeper:
    image: wurstmeister/zookeeper
    container_name: zookeeper
    ports:
      - 2181:2181
    volumes:
      - /root/playground/kafka/data/zookeeper/data:/data
      - /root/playground/kafka/data/zookeeper/datalog:/datalog
      - /root/playground/kafka/data/zookeeper/logs:/logs
    restart: always
  kafka1:
    image: wurstmeister/kafka
    depends_on:
      - zookeeper
    container_name: kafka1
    ports:
      - 9092:9092
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: 192.168.1.200:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://192.168.1.200:9092
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092
      KAFKA_LOG_DIRS: /data/kafka-data
      KAFKA_LOG_RETENTION_HOURS: 24
    volumes:
      - /root/playground/kafka/data/kafka1/data:/data/kafka-data
    restart: unless-stopped  
  kafka2:
    image: wurstmeister/kafka
    depends_on:
      - zookeeper
    container_name: kafka2
    ports:
      - 9093:9093
    environment:
      KAFKA_BROKER_ID: 2
      KAFKA_ZOOKEEPER_CONNECT: 192.168.1.200:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://192.168.1.200:9093
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9093
      KAFKA_LOG_DIRS: /data/kafka-data
      KAFKA_LOG_RETENTION_HOURS: 24
    volumes:
      - /root/playground/kafka/data/kafka2/data:/data/kafka-data
    restart: unless-stopped
  kafka3:
    image: wurstmeister/kafka
    depends_on:
      - zookeeper
    container_name: kafka3
    ports:
      - 9094:9094
    environment:
      KAFKA_BROKER_ID: 3
      KAFKA_ZOOKEEPER_CONNECT: 192.168.1.200:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://192.168.1.200:9094
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9094
      KAFKA_LOG_DIRS: /data/kafka-data
      KAFKA_LOG_RETENTION_HOURS: 24
    volumes:
      - /root/playground/kafka/data/kafka3/data:/data/kafka-data
    restart: unless-stopped
```

注意：yaml中的ip为虚拟机的局域网ip



## 部署kafka集群

```bash
docker-compose up -d
```



查看部署结果

```bash
[root@playground kafka]# docker-compose ps
  Name                 Command               State                         Ports                       
-------------------------------------------------------------------------------------------------------
kafka1      start-kafka.sh                   Up      0.0.0.0:9092->9092/tcp                            
kafka2      start-kafka.sh                   Up      0.0.0.0:9093->9093/tcp                            
kafka3      start-kafka.sh                   Up      0.0.0.0:9094->9094/tcp                            
zookeeper   /bin/sh -c /usr/sbin/sshd  ...   Up      0.0.0.0:2181->2181/tcp, 22/tcp, 2888/tcp, 3888/tcp
```

可以查看到zookeeper以及三个kafka的容器成功运行即可



## 测试集群可用性



### 创建主题

进入容器kafka1

```bash
docker exec -it kafka1 /bin/sh
```

创建主题yuki，三分区两副本

```bash
/opt/kafka/bin/kafka-topics.sh --create --topic yuki --zookeeper 192.168.1.200:2181 --partitions 3 --replication-factor 2
```

查看主题列表

```bash
/opt/kafka/bin/kafka-topics.sh --list --zookeeper 192.168.1.200:2181
```

查看主题详情

```bash
/opt/kafka/bin/kafka-topics.sh --describe --topic yuki --zookeeper 192.168.1.200:2181
```



### 开启生产者与消费者



#### 生产者

进入容器kafka1，执行

```bash
/opt/kafka/bin/kafka-console-producer.sh --topic yuki --broker-list 192.168.1.200:9092
```



#### 消费者

打开另一个ssh，进入kafka2，执行

```bash
/opt/kafka/bin/kafka-console-consumer.sh --topic yuki --bootstrap-server 192.168.1.200:9092 --from-beginning
```

若此时在两端的console中消费者能及时消费生产者产生的数据说明集群搭建成功