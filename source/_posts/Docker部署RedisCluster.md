---
title: Docker部署RedisCluster
date: 2022-05-24 21:24:47
tags: 
- Cache
categories:
- Web开发
---

## Prepare

<!-- more -->

### Config and Data Volumn

在宿主机上准备redis配置文件以及挂载的数据卷的目录，结构如下：

```bash
[root@playground redis]# tree .
.
├── docker-compose.yml
├── redis-6371
│   ├── conf
│   │   └── redis.conf
│   └── data
├── redis-6372
│   ├── conf
│   │   └── redis.conf
│   └── data
├── redis-6373
│   ├── conf
│   │   └── redis.conf
│   └── data
├── redis-6374
│   ├── conf
│   │   └── redis.conf
│   └── data
├── redis-6375
│   ├── conf
│   │   └── redis.conf
│   └── data
└── redis-6376
    ├── conf
    │   └── redis.conf
    └── data
```

说明

* `redis-<端口号>/conf/redis.conf`是redis实例启动的配置文件，内容如下

  ```bash
  port <实例暴露端口号，如6379>
  requirepass 1234
  bind 0.0.0.0
  protected-mode no
  daemonize no
  appendonly yes
  cluster-enabled yes 
  cluster-config-file nodes.conf
  cluster-node-timeout 5000
  cluster-announce-ip  <宿主机ip, 如192.168.1.200>
  cluster-announce-port <实例暴露端口号，如6379>
  cluster-announce-bus-port <实例暴露端口号 + 10000，如16379>
  ```

  

* `redis-<端口号>/data`是redis持久化的数据卷





### docker-compose

用来启动多个redis实例以及映射配置文件与数据卷

```yaml
version: "3"

services:
  redis-6371: 
    image: redis 
    container_name: redis-6371 
    restart: always 
    volumes: 
      - ./redis-6371/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-6371/data:/data
    ports:
      - 6371:6371
      - 16371:16371
    command:
      redis-server /usr/local/etc/redis/redis.conf

  redis-6372:
    image: redis
    container_name: redis-6372
    volumes:
      - ./redis-6372/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-6372/data:/data
    ports:
      - 6372:6372
      - 16372:16372
    command:
      redis-server /usr/local/etc/redis/redis.conf

  redis-6373:
    image: redis
    container_name: redis-6373
    volumes:
      - ./redis-6373/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-6373/data:/data
    ports:
      - 6373:6373
      - 16373:16373
    command:
      redis-server /usr/local/etc/redis/redis.conf
      
  redis-6374:
    image: redis
    container_name: redis-6374
    restart: always
    volumes:
      - ./redis-6374/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-6374/data:/data
    ports:
      - 6374:6374
      - 16374:16374
    command:
      redis-server /usr/local/etc/redis/redis.conf

  redis-6375:
    image: redis
    container_name: redis-6375
    volumes:
      - ./redis-6375/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-6375/data:/data
    ports:
      - 6375:6375
      - 16375:16375
    command:
      redis-server /usr/local/etc/redis/redis.conf

  redis-6376:
    image: redis
    container_name: redis-6376
    volumes:
      - ./redis-6376/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-6376/data:/data
    ports:
      - 6376:6376
      - 16376:16376
    command:
      redis-server /usr/local/etc/redis/redis.conf
```



## Initialize Redis Instance

```bash
cd <directory of your docker-compose file>
docker-compose up -d
```

检查实例是否启动成功

```bash
[root@playground redis]# docker-compose ps
   Name                 Command               State                             Ports                           
----------------------------------------------------------------------------------------------------------------
redis-6371   docker-entrypoint.sh redis ...   Up      0.0.0.0:16371->16371/tcp, 0.0.0.0:6371->6371/tcp, 6379/tcp
redis-6372   docker-entrypoint.sh redis ...   Up      0.0.0.0:16372->16372/tcp, 0.0.0.0:6372->6372/tcp, 6379/tcp
redis-6373   docker-entrypoint.sh redis ...   Up      0.0.0.0:16373->16373/tcp, 0.0.0.0:6373->6373/tcp, 6379/tcp
redis-6374   docker-entrypoint.sh redis ...   Up      0.0.0.0:16374->16374/tcp, 0.0.0.0:6374->6374/tcp, 6379/tcp
redis-6375   docker-entrypoint.sh redis ...   Up      0.0.0.0:16375->16375/tcp, 0.0.0.0:6375->6375/tcp, 6379/tcp
redis-6376   docker-entrypoint.sh redis ...   Up      0.0.0.0:16376->16376/tcp, 0.0.0.0:6376->6376/tcp, 6379/tcp
```



## Start Cluster

进入任意一个实例中

```bash
docker exec -it redis-6371 /bin/sh
```

执行

```bash
redis-cli -a 1234 --cluster create 192.168.1.200:6371 192.168.1.200:6372 192.168.1.200:6373 192.168.1.200:6374 192.168.1.200:6375 192.168.1.200:6376 --cluster-replicas 1
```

执行结果

```bash
# redis-cli -a 1234 --cluster create 192.168.1.200:6371 192.168.1.200:6372 192.168.1.200:6373 192.168.1.200:6374 192.168.1.200:6375 192.168.1.200:6376 --cluster-replicas 1
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
>>> Performing hash slots allocation on 6 nodes...
Master[0] -> Slots 0 - 5460
Master[1] -> Slots 5461 - 10922
Master[2] -> Slots 10923 - 16383
Adding replica 192.168.1.200:6375 to 192.168.1.200:6371
Adding replica 192.168.1.200:6376 to 192.168.1.200:6372
Adding replica 192.168.1.200:6374 to 192.168.1.200:6373
>>> Trying to optimize slaves allocation for anti-affinity
[WARNING] Some slaves are in the same host as their master
M: b0e9b492aa43fef1970aa8e3ca66f59ef3fb3097 192.168.1.200:6371
   slots:[0-5460] (5461 slots) master
M: 77ef976879816a2b600173bef8da8fb75ea0eaaf 192.168.1.200:6372
   slots:[5461-10922] (5462 slots) master
M: 9ccf171a890134c2589b7170399a0cf10a5e4227 192.168.1.200:6373
   slots:[10923-16383] (5461 slots) master
S: 7b6c90ddf3d63c06063ac34c97a95da72008ca81 192.168.1.200:6374
   replicates 9ccf171a890134c2589b7170399a0cf10a5e4227
S: df88347e5ba5c8e74306d6801deb1282f11de837 192.168.1.200:6375
   replicates b0e9b492aa43fef1970aa8e3ca66f59ef3fb3097
S: 942b16d7717822ee6776e38d9b15e04f6f7cf149 192.168.1.200:6376
   replicates 77ef976879816a2b600173bef8da8fb75ea0eaaf
Can I set the above configuration? (type 'yes' to accept): yes
>>> Nodes configuration updated
>>> Assign a different config epoch to each node
>>> Sending CLUSTER MEET messages to join the cluster
Waiting for the cluster to join

>>> Performing Cluster Check (using node 192.168.1.200:6371)
M: b0e9b492aa43fef1970aa8e3ca66f59ef3fb3097 192.168.1.200:6371
   slots:[0-5460] (5461 slots) master
   1 additional replica(s)
S: 7b6c90ddf3d63c06063ac34c97a95da72008ca81 192.168.1.200:6374
   slots: (0 slots) slave
   replicates 9ccf171a890134c2589b7170399a0cf10a5e4227
S: 942b16d7717822ee6776e38d9b15e04f6f7cf149 192.168.1.200:6376
   slots: (0 slots) slave
   replicates 77ef976879816a2b600173bef8da8fb75ea0eaaf
M: 77ef976879816a2b600173bef8da8fb75ea0eaaf 192.168.1.200:6372
   slots:[5461-10922] (5462 slots) master
   1 additional replica(s)
M: 9ccf171a890134c2589b7170399a0cf10a5e4227 192.168.1.200:6373
   slots:[10923-16383] (5461 slots) master
   1 additional replica(s)
S: df88347e5ba5c8e74306d6801deb1282f11de837 192.168.1.200:6375
   slots: (0 slots) slave
   replicates b0e9b492aa43fef1970aa8e3ca66f59ef3fb3097
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
```

可以看到，redis cluster配置为三主三从，配置完成



## Test

进入6371的redis-cli

```bash
docker exec -it redis-6371 redis-cli -c -h localhost -p 6371 --pass 1234
```

SET一个值

```bash
localhost:6371> SET A 123
-> Redirected to slot [6373] located at 192.168.1.200:6372
OK
(63.16s)
```

重定向到了6372.....并且值成功设置到了6372节点



进入6374的redis-cli

```bash
docker exec -it redis-6374 redis-cli -c -h localhost -p 6374 --pass 1234
```

GET刚刚设置的A

```bash
localhost:6374> GET A
-> Redirected to slot [6373] located at 192.168.1.200:6372
"123"
```

重定向到了6372.....并且获取到了刚刚SET进入的A



至此redis cluster搭建与测试完成