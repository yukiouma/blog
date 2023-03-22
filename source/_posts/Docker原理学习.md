---
title: Docker原理学习
date: 2023-03-22 15:30:00
tags: 
- Docker
categories:
- DevOps
---

# 容器原理 - chroot

> chroot是Linux下的一个操作，针对某个进程设置一个根目录，该进程与其子进程都无法访问根目录以外的其它文件

使用例子：

```bash
$ mkdir ./rootfs && cd ./rootfs
$ docker export $(docker create busybox) -o busybox.tar
$ tar -xf busybox.tar
$ chroot $PWD /bin/sh
```

上面的命令将busybox镜像中的所有目录放入到新建的`rootfs`文件夹中并解压，然后使用`chroot`命令将当前目录作为`/bin/sh`进程的根目录，然后可以进入sh的交互

<!-- more -->

```bash
$ chroot $PWD /bin/sh
/ # pwd
/
/ # cd ..
/ # ls
bin    dev    etc    home   lib    lib64  proc   root   sys    tmp    usr    var
```

到这里我们实现了文件访问的隔离，但是我们在这个进程中查询一下网络的情况

```bash
/ # ip route
default via 192.168.245.2 dev ens33 
172.17.0.0/16 dev docker0 scope link  src 172.17.0.1 
192.168.245.0/24 dev ens33 scope link  src 192.168.245.100 
/ # hostname
yuki
```

跟我们的宿主机的网络是一样的，说明网络并没有进行隔离

要实现隔离，还需要下面的内容

* Namespace

  对内核资源进行隔离，使得容器中的进程都可以在单独的命名空间中运行，并且只可以访问当前容器命名空间的资源，可以隔离进程ID，主机名，用户ID，文件名，网络访问和进程间通信相关资源，主要用到5中命名空间

  1. pid namespace：隔离进程
  2. net namespace：隔离网络接口
  3. mnt namespace：文件系统挂载点的隔离
  4. ipc namespace：信号量，消息队列和共享内存的隔离
  5. uts namespace：主机名和域名隔离

* Cgroup

  对进程和进程组对资源利用的限制，如CPU的使用，内存，磁盘I/O，网络的使用

* 联合文件系统

  镜像构建和容器运行环境

  通过创建文件层进程操作的文件系统，常用的有AUFS，Overlay和Devicemapper





# OCI

开放容器标准，Open Container Intiative，一个轻量级，开放的治理结构

* 容器运行时标准
* 容器镜像标准



# Docker架构



## 客户端

命令行，restful API，以及各种语言维护的SDK等



## 服务端

### dockerd

docker daemon，负责响应和处理来自客户端的请求，然后转换为Docker的具体操作

### containerd

docker服务端通过containerd-shim启动并管理runC

### runC

用来运行容器的轻量级工具



![image-20230315212304543](image-20230315212304543.png)



查看dockerd的进程

```bash
$ sudo ps aux | grep dockerd
root        1034  0.1  1.0 1680092 86440 ?       Ssl  12:41   0:03 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
```

可以看到dockerd进程pid是1034，我们查看一下该进程的子进程

```bash
$ sudo pstree -l -a -A 1034
dockerd -H fd:// --containerd=/run/containerd/containerd.sock
  |-docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 16686 -container-ip 172.17.0.2 -container-port 16686
  |   `-5*[{docker-proxy}]
  |-docker-proxy -proto tcp -host-ip :: -host-port 16686 -container-ip 172.17.0.2 -container-port 16686
  |   `-7*[{docker-proxy}]
  |-docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 3306 -container-ip 172.17.0.4 -container-port 3306
  |   `-5*[{docker-proxy}]
  |-docker-proxy -proto tcp -host-ip :: -host-port 3306 -container-ip 172.17.0.4 -container-port 3306
  |   `-6*[{docker-proxy}]
  ......
  ....
  ...
  ..
  `-12*[{dockerd}]
```





# Image

构建Docker镜像的时候，Dockerfile中的每一个命令都会提交一个镜像层，在`/var/lib/docker/overlay2`中查看镜像层 

![image-20230315214202581](image-20230315214202581.png)



## 构建

基于Dockerfile

尽量使用构建缓存

* 从当前构建层开始，比较所有的子镜像，如果所有的构建指令和当前是否完全一致，如果一致，则使用缓存，否则不适用缓存
* 一般而言只比较指令，但是ADD和COPY除外
* 对于ADD和COPY指令要检查命令一致以外，还要计算即将拷贝到容器的文件计算校验和，校验和完全一致，才算命中缓存

书写Dockerfile的时候尽可能把不容易改变的指令放在前面，容易改变的指令放在末尾，尽可能将镜像缓存利用上

CMD 与 ENTRYPOINT

* 使用CMD设置的命令可以被docker run后面的参数直接覆盖

* 使用ENTRYPOINT的命令需使用--entrypoint参数才可以覆盖Dockerfile中定义的指令

推荐使用WORKDIR指定工作路径，避免使用`RUN cd/workpath && do something`这种形式



# Container

容器组成

包含若干个只读的image layer，与一个可读写的container layer

![image-20230315214721574](image-20230315214721574.png)



## Life Cycle

* created
* running
* stopped
* paused
* deleted

![image-20230315214434189](image-20230315214434189.png)



## 操作

* 终止容器

  docker向容器发送`SIGTERM`信号，如果容器能正常接受并处理，则等待进程结束并退出。如果等待一段时间后依旧没有退出，则直接发送`SIGKILL`杀死进程

  

* 导入镜像

  ``` bash
  $ docker import <your file> <image name>:<tag>
  ```

  

* 导出容器

  ```bash
  $ docker export <container>
  ```

  



# 安全

## VM与Docker的区别

* VM通过管理系统模拟出完整的CPU，内存，网络等硬件，在这些模拟的硬件的基础上构造内核和操作系统，天然有用很高的隔离性
* Docker通过Namespace实现文件系统，PID，网络等隔离，通过cgroup来限制CPU，内存的使用，容器的隔离靠内核提供

三个主要问题

* 镜像软件存在漏洞

* 仓库漏洞

* 用户程序漏洞

  

内核Namespace的隔离性不够：关键部分内容没有完全隔离，包括一些系统的关键性目录，如`/sys`和`/proc`

* 使用Capabilities划分权限
* 使用SELinux，AppArmor，GRSecurity等安全组件
* 容器使用资源限制



## 安全问题

权限提升，信息泄露等



## Docker自身安全性改进

User Namespace：用来作容器内用户和主机的用户的隔离，1.10版本后，使用User Namespace做用户隔离实现容器中root用户映射到主机的非root用户



## 保证镜像安全

私有镜像安装扫描组件，对上传的镜像进行检查，通过与漏洞披露（CVE）*数据库*进行比对确认是否被篡改

与镜像仓库通信一定要用https协议



## 资源限制

运行容器时建议田间资源限制参数

* --cpus
* --memory
* --pids-limit：限制容器pid个数



## 安全容器

安全容器中的每个容器都运行在一个单独的微型虚拟机中，拥有独立的OS和内核，并有虚拟化层的安全隔离

推荐方案：Kata Container



# 容器监控



## docker stats

```bash
$ docker stats <container name>
CONTAINER ID   NAME       CPU %     MEM USAGE / LIMIT     MEM %     NET I/O       BLOCK I/O   PIDS
4fe07ba72375   registry   0.02%     7.062MiB / 7.741GiB   0.09%     1.44kB / 0B   17MB / 0B   6
```



## 其它开源组件

* cAdvisor

* Prometheus



## 监控原理

### 资源数据监控来源

第三方组件定时读取linux主机上相关的文件，然后展示给用户

cgroups(`/sys/fs/cgroup`)可以用于容器资源的限制，还可以提供容器的资源使用率

```bash
$ ls -l /sys/fs/cgroup/
total 0
dr-xr-xr-x 5 root root  0 Mar 15 12:41 blkio
lrwxrwxrwx 1 root root 11 Mar 15 12:41 cpu -> cpu,cpuacct
lrwxrwxrwx 1 root root 11 Mar 15 12:41 cpuacct -> cpu,cpuacct
dr-xr-xr-x 5 root root  0 Mar 15 12:41 cpu,cpuacct
dr-xr-xr-x 3 root root  0 Mar 15 12:41 cpuset
dr-xr-xr-x 5 root root  0 Mar 15 12:41 devices
dr-xr-xr-x 4 root root  0 Mar 15 12:41 freezer
dr-xr-xr-x 3 root root  0 Mar 15 12:41 hugetlb
dr-xr-xr-x 5 root root  0 Mar 15 12:41 memory
lrwxrwxrwx 1 root root 16 Mar 15 12:41 net_cls -> net_cls,net_prio
dr-xr-xr-x 3 root root  0 Mar 15 12:41 net_cls,net_prio
lrwxrwxrwx 1 root root 16 Mar 15 12:41 net_prio -> net_cls,net_prio
dr-xr-xr-x 3 root root  0 Mar 15 12:41 perf_event
dr-xr-xr-x 5 root root  0 Mar 15 12:41 pids
dr-xr-xr-x 3 root root  0 Mar 15 12:41 rdma
dr-xr-xr-x 6 root root  0 Mar 15 12:41 systemd
dr-xr-xr-x 6 root root  0 Mar 15 12:41 unified
```

以memory为例

我们先找到一个容器的id

```bash
$ docker ps --no-trunc --filter=name=jaeger --format="{{.ID}}"
acfd253482a3fe27db9d94a18e524ff08532a668e23e047375ab452106d4b9ae
```

容器jaeger的id是acfd253482a3fe27db9d94a18e524ff08532a668e23e047375ab452106d4b9ae

在`/sys/fs/cgroup/memory/docker`下找到该id的文件夹

```bash
$ ls -l /sys/fs/cgroup/memory/docker/acfd253482a3fe27db9d94a18e524ff08532a668e23e047375ab452106d4b9ae/
total 0
drwxr-xr-x 2 root root 0 Mar 15 12:41 ./
drwxr-xr-x 5 root root 0 Mar 15 12:41 ../
-rw-r--r-- 1 root root 0 Mar 15 15:41 cgroup.clone_children
--w--w--w- 1 root root 0 Mar 15 12:41 cgroup.event_control
-rw-r--r-- 1 root root 0 Mar 15 12:41 cgroup.procs
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.failcnt
--w------- 1 root root 0 Mar 15 15:41 memory.force_empty
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.failcnt
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.limit_in_bytes
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.max_usage_in_bytes
-r--r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.slabinfo
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.tcp.failcnt
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.tcp.limit_in_bytes
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.tcp.max_usage_in_bytes
-r--r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.tcp.usage_in_bytes
-r--r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.usage_in_bytes
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.limit_in_bytes
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.max_usage_in_bytes
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.move_charge_at_immigrate
-r--r--r-- 1 root root 0 Mar 15 15:41 memory.numa_stat
-rw-r--r-- 1 root root 0 Mar 15 12:41 memory.oom_control
---------- 1 root root 0 Mar 15 15:41 memory.pressure_level
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.soft_limit_in_bytes
-r--r--r-- 1 root root 0 Mar 15 15:41 memory.stat
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.swappiness
-r--r--r-- 1 root root 0 Mar 15 15:41 memory.usage_in_bytes
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.use_hierarchy
-rw-r--r-- 1 root root 0 Mar 15 15:41 notify_on_release
-rw-r--r-- 1 root root 0 Mar 15 15:41 tasks
```

查看文件`memory.kmem.limit_in_bytes`，查看容器的内存限制

```bash
$ cat /sys/fs/cgroup/memory/docker/acfd253482a3fe27db9d94a18e524ff08532a668e23e047375ab452106d4b9ae/memory.kmem.limit_in_bytes 
9223372036854771712
```

查看文件`memory.usage_in_bytes`，查看当前容器使用的内存大小

```bash
$ cat /sys/fs/cgroup/memory/docker/acfd253482a3fe27db9d94a18e524ff08532a668e23e047375ab452106d4b9ae/memory.usage_in_bytes 
41271296
```



### 网络数据监控来源

查看容器pid

```bash
$ docker inspect jaeger | grep '"Pid"'
            "Pid": 1673,
```

看到容器jaeger的pid是1673

查看主机上进程1673的网络数据

```bash
$ cat /proc/1673/net/dev
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo:  158764    3051    0    0    0     0          0         0   158764    3051    0    0    0     0       0          0
  eth0:    1466      19    0    0    0     0          0         0        0       0    0    0    0     0       0          0
```

可以看到进程的网络数据信息





# Namespace

Linux内核的一项功能，可以对内核资源进行分区，使得一组进程看到一组资源，另一组进程看到另一组资源。这些资源可以是：

* PID

* hostname

* 用户

* 文件名

* 网络访问相关的名称和进程间通信

  

> unshare命令可以方便模拟出不同的namespace的情形

Docker使用了以下的namespace：



## Mount Namespace

隔离不同进程或者进程组看到的挂载点，实现容器内只能看到自己的挂载信息，容器内的挂载操作不会影响到主机的挂载目录

挂载点的概念：TODO



实验：使用unshare创建一个mount namespace的进程，并在里面实现挂载操作，再查看是否影响到主机的目录

```bash
yuki@yuki:~$ sudo unshare --mount --fork /bin/bash
root@yuki:/home/yuki# mkdir /tmp/tmpfs
root@yuki:/home/yuki# mount -t tmpfs -o size=20M tmpfs /tmp/tmpfs
root@yuki:/home/yuki# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda4        36G   26G  7.6G  78% /
udev            3.9G     0  3.9G   0% /dev
tmpfs           3.9G     0  3.9G   0% /dev/shm
tmpfs           793M  1.6M  792M   1% /run
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           793M     0  793M   0% /run/user/0
tmpfs           3.9G     0  3.9G   0% /sys/fs/cgroup
/dev/loop0       64M   64M     0 100% /snap/core20/1822
/dev/loop1       64M   64M     0 100% /snap/core20/1828
/dev/loop2       50M   50M     0 100% /snap/snapd/18357
/dev/loop4       92M   92M     0 100% /snap/lxd/23991
/dev/loop3       50M   50M     0 100% /snap/snapd/17950
/dev/loop5       92M   92M     0 100% /snap/lxd/24061
/dev/sda2       2.0G  209M  1.6G  12% /boot
overlay          36G   26G  7.6G  78% /var/lib/docker/overlay2/b59725fa1fc5d5c867b3029934eb637569966d5f3a473831b93c48512888dae1/merged
overlay          36G   26G  7.6G  78% /var/lib/docker/overlay2/8f8f9d90fadbba79a64dfba27eccec253cb6579be2c611c3969b9f51ef26248c/merged
overlay          36G   26G  7.6G  78% /var/lib/docker/overlay2/69266a1d6e7daa85d23dab94bea34bbcf162dbb144dc6ad38fe7e848dc8c8626/merged
tmpfs            20M     0   20M   0% /tmp/tmpfs
```

可以看到最后一条记录中，tmpfs被正确挂载到`tmp/tmpfs`中了

这时我们退出该进程，再查看挂载信息

```bash
root@yuki:/home/yuki# exit
exit
yuki@yuki:~$ df -h
Filesystem      Size  Used Avail Use% Mounted on
udev            3.9G     0  3.9G   0% /dev
tmpfs           793M  1.6M  792M   1% /run
/dev/sda4        36G   26G  7.6G  78% /
tmpfs           3.9G     0  3.9G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           3.9G     0  3.9G   0% /sys/fs/cgroup
/dev/loop0       64M   64M     0 100% /snap/core20/1822
/dev/loop1       64M   64M     0 100% /snap/core20/1828
/dev/loop2       50M   50M     0 100% /snap/snapd/18357
/dev/loop4       92M   92M     0 100% /snap/lxd/23991
/dev/loop3       50M   50M     0 100% /snap/snapd/17950
/dev/loop5       92M   92M     0 100% /snap/lxd/24061
/dev/sda2       2.0G  209M  1.6G  12% /boot
tmpfs           793M     0  793M   0% /run/user/0
```

可以看到，`tmp/tmpfs`挂载信息并没有再主机中出现，说明mount namespace成功隔离了挂载点



## Process ID Namespace

作用是隔离进程，例如某个进程在主机中的进程是122，但是在PID Namespace中可以实现该进程在容器中看到的PID是1



实验：使用unshare创建一个PID Namespace进程，查看进程内与主机中进程的区别

```bash
yuki@yuki:~$ sudo unshare --pid --fork --mount-proc /bin/bash
root@yuki:/home/yuki# ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.1  0.0   7236  4060 pts/13   S    13:59   0:00 /bin/bash
root           8  0.0  0.0   8888  3296 pts/13   R+   14:00   0:00 ps aux
```

可以看到，该进程的PID为1

我们在外面查看一下该进程

```bash
yuki@yuki:~$ ps aux | tail -n 3
yuki       39328  0.2  0.0   8268  5024 pts/15   S    14:06   0:00 bash
yuki       39413  0.0  0.0   8888  3328 pts/15   R+   14:07   0:00 ps aux
yuki       39414  0.0  0.0   5512   580 pts/15   S+   14:07   0:00 tail -n 3
```

可以看到bash的PID是39328



## Network Namespace

net namespace用来隔离网络设备，IP地址和端口信息，让每个进程持有独立的IP地址，端口和网卡

实验：创建一个net namespace隔离的进程，查看他与主机进程中网络信息的区别

```bash
yuki@yuki:~$ sudo unshare --net --fork /bin/bash
root@yuki:/home/yuki# ip a
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
```

主机查看

```bash
yuki@yuki:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 1000
    link/ether 00:0c:29:27:ec:90 brd ff:ff:ff:ff:ff:ff
    inet 192.168.245.100/24 brd 192.168.245.255 scope global ens33
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:fe27:ec90/64 scope link 
       valid_lft forever preferred_lft forever
3: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:ce:eb:4a:0f brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:ceff:feeb:4a0f/64 scope link 
       valid_lft forever preferred_lft forever
5: veth04eb3e9@if4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master docker0 state UP group default 
    link/ether ca:2a:76:aa:5e:0a brd ff:ff:ff:ff:ff:ff link-netnsid 2
    inet6 fe80::c82a:76ff:feaa:5e0a/64 scope link 
       valid_lft forever preferred_lft forever
7: vethbe51622@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master docker0 state UP group default 
    link/ether ae:da:5e:09:2f:7b brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::acda:5eff:fe09:2f7b/64 scope link 
       valid_lft forever preferred_lft forever
9: veth1feb11f@if8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master docker0 state UP group default 
    link/ether 02:40:26:18:f5:ad brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet6 fe80::40:26ff:fe18:f5ad/64 scope link 
       valid_lft forever preferred_lft forever
```

可以看到区别还是很大的....



## Interprocess Communication Namespace

IPC Namespace用来隔离进程间通信

PID Namespace和IPC Namespace一起使用可以实现同一个IPC Namespace内的进程可以彼此通信，不同IPC Namespace的进程不能通信

实验：使用unshare创建一个IPC Namespace进程，并在进程内创建一个系统间通信队列，查看系统外部是否能查看到该通信队列

```bash
yuki@yuki:~$ sudo unshare --ipc --fork /bin/bash
root@yuki:/home/yuki# ipcs -q

------ Message Queues --------
key        msqid      owner      perms      used-bytes   messages    

root@yuki:/home/yuki# ipcmk -Q
Message queue id: 0
root@yuki:/home/yuki# ipcs -q

------ Message Queues --------
key        msqid      owner      perms      used-bytes   messages    
0xf061fcc8 0          root       644        0            0   
```

可以看到在进程内通信队列被创建

我们重现打开一个终端，查看通信队列

```bash
yuki@yuki:~$ ipcs -q

------ Message Queues --------
key        msqid      owner      perms      used-bytes   messages 
```

发现是看不到该通信队列，说明IPC被成功隔离



## UTS Namespace

允许每个UTS Namespace拥有一个独立的主机名

实验：使用unshare创建一个UTS Namespace进程，查看进程内与主机中进程的区别

```bash
yuki@yuki:~$ sudo unshare --uts --fork /bin/bash
root@yuki:/home/yuki# hostname
yuki
root@yuki:/home/yuki# hostname -b demo
root@yuki:/home/yuki# hostname
demo
```

可以看到进程内hostname成功被改为demo

我们重现打开一个终端，查看hostname

```bash
yuki@yuki:~$ hostname
yuki
```

可以看到外部的hostname没有被影响到



## User Namespace

可以实现用户在容器内拥有root权限，而主机上只是普通用户

实验：使用普通用户创建一个user namespace的进程，查看该用户在进程内是否为root用户，并且该root用户是否能执行一些主机的root命令

```bash
yuki@yuki:~$ unshare --user -r /bin/bash
root@yuki:~# id
uid=0(root) gid=0(root) groups=0(root),65534(nogroup)
root@yuki:~# reboot
Failed to open initctl fifo: Permission denied
Failed to talk to init daemon.
```

可以看到，进程内用户变成了root用户，但是却无法执行真正的root用户的reboot命令，说明user namespace进行了有效隔离





# Cgroups

control groups是Linux内核的一个功能，可以实现限制进程或者进程组的资源（如CPU，内存和磁盘IO等）

> 注意，cgroup可以限制资源，但不能保证资源的使用，比如限制了一个g的内存使用，但是不一定能保证进程能用满一个g

功能：

* 资源限制：限制资源使用量
* 优先级控制：不同组可以有不同资源的使用优先级
* 审计：计算控制组的资源使用情况
* 控制：控制进程的挂起和恢复

cgroups有三个核心概念：

* 子系统：subsystem

  一个子系统代表一类资源调度控制器

* 控制组：cgroup

  一组进程和一组带有参数的子系统的关联关系，例如一个进程使用子系统限制了CPU时间的使用，那么该进程和子系统称为一个控制组

* 层级树：hierarchy

  一些列控制组按照树状结构排列而成，子控制组默认持有所有父控制组的属性

  



## subsystem

一个子系统代表一类资源调度控制器

查看当前挂载的子系统信息

```bash
$ sudo mount -t cgroup
cgroup on /sys/fs/cgroup/systemd type cgroup (rw,nosuid,nodev,noexec,relatime,xattr,name=systemd)
cgroup on /sys/fs/cgroup/cpu,cpuacct type cgroup (rw,nosuid,nodev,noexec,relatime,cpu,cpuacct)
cgroup on /sys/fs/cgroup/blkio type cgroup (rw,nosuid,nodev,noexec,relatime,blkio)
cgroup on /sys/fs/cgroup/perf_event type cgroup (rw,nosuid,nodev,noexec,relatime,perf_event)
cgroup on /sys/fs/cgroup/memory type cgroup (rw,nosuid,nodev,noexec,relatime,memory)
cgroup on /sys/fs/cgroup/net_cls,net_prio type cgroup (rw,nosuid,nodev,noexec,relatime,net_cls,net_prio)
cgroup on /sys/fs/cgroup/cpuset type cgroup (rw,nosuid,nodev,noexec,relatime,cpuset)
cgroup on /sys/fs/cgroup/freezer type cgroup (rw,nosuid,nodev,noexec,relatime,freezer)
cgroup on /sys/fs/cgroup/pids type cgroup (rw,nosuid,nodev,noexec,relatime,pids)
cgroup on /sys/fs/cgroup/rdma type cgroup (rw,nosuid,nodev,noexec,relatime,rdma)
cgroup on /sys/fs/cgroup/devices type cgroup (rw,nosuid,nodev,noexec,relatime,devices)
cgroup on /sys/fs/cgroup/hugetlb type cgroup (rw,nosuid,nodev,noexec,relatime,hugetlb)
```

子系统的管理位置

```bash
$ ls -al /sys/fs/cgroup/
total 0
drwxr-xr-x 15 root root 380 Mar 15 12:41 .
drwxr-xr-x 10 root root   0 Mar 15 12:41 ..
dr-xr-xr-x  5 root root   0 Mar 15 12:41 blkio
lrwxrwxrwx  1 root root  11 Mar 15 12:41 cpu -> cpu,cpuacct
lrwxrwxrwx  1 root root  11 Mar 15 12:41 cpuacct -> cpu,cpuacct
dr-xr-xr-x  5 root root   0 Mar 15 12:41 cpu,cpuacct
dr-xr-xr-x  3 root root   0 Mar 15 12:41 cpuset
dr-xr-xr-x  5 root root   0 Mar 15 12:41 devices
dr-xr-xr-x  4 root root   0 Mar 15 12:41 freezer
dr-xr-xr-x  3 root root   0 Mar 15 12:41 hugetlb
dr-xr-xr-x  5 root root   0 Mar 15 12:41 memory
lrwxrwxrwx  1 root root  16 Mar 15 12:41 net_cls -> net_cls,net_prio
dr-xr-xr-x  3 root root   0 Mar 15 12:41 net_cls,net_prio
lrwxrwxrwx  1 root root  16 Mar 15 12:41 net_prio -> net_cls,net_prio
dr-xr-xr-x  3 root root   0 Mar 15 12:41 perf_event
dr-xr-xr-x  5 root root   0 Mar 15 12:41 pids
dr-xr-xr-x  3 root root   0 Mar 15 12:41 rdma
dr-xr-xr-x  6 root root   0 Mar 15 12:41 systemd
dr-xr-xr-x  6 root root   0 Mar 15 12:41 unified
```





### cpu子系统

创建cpu子系统，在`/sys/fs/cgroup/cpu`下面创建一个和目录，就等于创建了一个cpu子系统，例如创建一个叫`mydocker`的控制组

```bash
root@yuki:~# mkdir /sys/fs/cgroup/cpu/mydocker
root@yuki:~# ls /sys/fs/cgroup/cpu/mydocker/
cgroup.clone_children  cpuacct.usage_all          cpuacct.usage_sys   cpu.shares      notify_on_release
cgroup.procs           cpuacct.usage_percpu       cpuacct.usage_user  cpu.stat        tasks
cpuacct.stat           cpuacct.usage_percpu_sys   cpu.cfs_period_us   cpu.uclamp.max
cpuacct.usage          cpuacct.usage_percpu_user  cpu.cfs_quota_us    cpu.uclamp.min
```

可以看到，创建文件夹后，文件夹中被自动放置了文件

* cpu.cfs_quota_us

  限制进程的cpu使用时间总量，单位是微秒，100000微妙 = 可以使用一个核，只要在该文件中写入100000，则该cgroup关联的pid进程最多仅能使用一个核

* tasks

  放置管理的进程的pid，只要将进程pid放入该文件，该进程的cpu使用就会收到该cgroup的限制

  

> 删除子系统：root@yuki:~# rmdir /sys/fs/cgroup/cpu/mydocker/



### memory子系统

创建memory子系统，在`/sys/fs/cgroup/memory`下面创建一个和目录，就等于创建了一个memory子系统，例如创建一个叫`mydocker`的控制组

```bash
root@yuki:~# ls /sys/fs/cgroup/memory/mydocker/
cgroup.clone_children           memory.kmem.tcp.failcnt             memory.oom_control
cgroup.event_control            memory.kmem.tcp.limit_in_bytes      memory.pressure_level
cgroup.procs                    memory.kmem.tcp.max_usage_in_bytes  memory.soft_limit_in_bytes
memory.failcnt                  memory.kmem.tcp.usage_in_bytes      memory.stat
memory.force_empty              memory.kmem.usage_in_bytes          memory.swappiness
memory.kmem.failcnt             memory.limit_in_bytes               memory.usage_in_bytes
memory.kmem.limit_in_bytes      memory.max_usage_in_bytes           memory.use_hierarchy
memory.kmem.max_usage_in_bytes  memory.move_charge_at_immigrate     notify_on_release
memory.kmem.slabinfo            memory.numa_stat  
```

可以看到，创建文件夹后，文件夹中被自动放置了文件

* memory.limit_in_bytes

  代表关联了子系统的进程可以使用的内存总量，单位是byte

* tasks

  放置管理的进程的pid，只要将进程pid放入该文件，该进程的内存使用就会收到该cgroup的限制

  

> 删除子系统：root@yuki:~# rmdir /sys/fs/cgroup/memory/mydocker/





**实验**：docker如何使用memory子系统

> 创建一个nginx容器，限制内存使用是1g，查看memory子系统下面的变化是否符合预期

创建容器

```bash
root@yuki:~# docker run -it -m=1g nginx:1.23
WARNING: Your kernel does not support swap limit capabilities or the cgroup is not mounted. Memory limited without swap.
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2023/03/17 14:09:30 [notice] 1#1: using the "epoll" event method
2023/03/17 14:09:30 [notice] 1#1: nginx/1.23.2
2023/03/17 14:09:30 [notice] 1#1: built by gcc 10.2.1 20210110 (Debian 10.2.1-6) 
2023/03/17 14:09:30 [notice] 1#1: OS: Linux 5.4.0-144-generic
2023/03/17 14:09:30 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1048576:1048576
2023/03/17 14:09:30 [notice] 1#1: start worker processes
2023/03/17 14:09:30 [notice] 1#1: start worker process 29
2023/03/17 14:09:30 [notice] 1#1: start worker process 30
```

看到容器创建成功，接下来我们到查看一下该容器的id

```bash
root@yuki:~# docker ps --no-trunc | grep nginx
ff22d0de9064f96c87df1d7fc33adccc7591ced70ea31dbd5ac188af5e765f57   nginx:1.23                      "/docker-entrypoint.sh nginx -g 'daemon off;'"     2 minutes ago   Up 2 minutes   80/tcp                                                                                                                                          frosty_mahavira
```

可以看到容器的id是ff22d0de9064f96c87df1d7fc33adccc7591ced70ea31dbd5ac188af5e765f57

接下来我们进入memory子系统中的docker文件夹

```bash
root@yuki:~# ls -l /sys/fs/cgroup/memory/docker/
total 0
drwxr-xr-x 2 root root 0 Mar 15 12:41 4fe07ba72375d3898a9959fc95243ee2055e4744780170031114a69aea4a21b1
drwxr-xr-x 2 root root 0 Mar 15 12:41 513ee9dcebf6bd5202d1db5b7a1ef50efdffa17a23295003e1b31489c0b544bf
drwxr-xr-x 2 root root 0 Mar 15 12:41 acfd253482a3fe27db9d94a18e524ff08532a668e23e047375ab452106d4b9ae
-rw-r--r-- 1 root root 0 Mar 15 15:41 cgroup.clone_children
--w--w--w- 1 root root 0 Mar 15 15:41 cgroup.event_control
-rw-r--r-- 1 root root 0 Mar 15 15:41 cgroup.procs
drwxr-xr-x 2 root root 0 Mar 17 14:09 ff22d0de9064f96c87df1d7fc33adccc7591ced70ea31dbd5ac188af5e765f57
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.failcnt
--w------- 1 root root 0 Mar 15 15:41 memory.force_empty
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.failcnt
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.limit_in_bytes
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.max_usage_in_bytes
-r--r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.slabinfo
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.tcp.failcnt
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.tcp.limit_in_bytes
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.tcp.max_usage_in_bytes
-r--r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.tcp.usage_in_bytes
-r--r--r-- 1 root root 0 Mar 15 15:41 memory.kmem.usage_in_bytes
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.limit_in_bytes
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.max_usage_in_bytes
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.move_charge_at_immigrate
-r--r--r-- 1 root root 0 Mar 15 15:41 memory.numa_stat
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.oom_control
---------- 1 root root 0 Mar 15 15:41 memory.pressure_level
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.soft_limit_in_bytes
-r--r--r-- 1 root root 0 Mar 15 15:41 memory.stat
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.swappiness
-r--r--r-- 1 root root 0 Mar 15 15:41 memory.usage_in_bytes
-rw-r--r-- 1 root root 0 Mar 15 15:41 memory.use_hierarchy
-rw-r--r-- 1 root root 0 Mar 15 15:41 notify_on_release
-rw-r--r-- 1 root root 0 Mar 15 15:41 tasks
```

可以看到存在ff22d0de9064f96c87df1d7fc33adccc7591ced70ea31dbd5ac188af5e765f57这个文件夹

然后我们进入该文件夹，查看一下`memory.limit_in_bytes`文件

```bash
root@yuki:~# cat /sys/fs/cgroup/memory/docker/ff22d0de9064f96c87df1d7fc33adccc7591ced70ea31dbd5ac188af5e765f57/memory.limit_in_bytes 
1073741824
```

1073741824 / 1024 / 1024 / 1024 = 1，刚好是我们传入的限制参数1g



# Docker组件



## docker相关

### docker & dockerd

* docker

  客户端，向dockerd返送请求

* dockerd

  接受docker的请求，并将执行结果返回给docker

交互方式

> docker与dockerd通信形式需要保持一致

* UNIX套接字与服务端通信

  配置格式是`unix://<socker_path>`，默认dockerd生产的socket文件路径是`/var/run/docker.sock`，默认方式

* 通过TCP与服务端通信

  配置格式是`tcp://host:port`

* 通过文件描述符的方式

  配置格式是`fd://`



### docker-init

在Linux系统中，init进程是1号进程，当主机进程出现问题时，init进程可以回收这些问题进程

在容器内部，当业务进程没有能力回收子进程的时候，执行docker run启动容器的时候可以添加--init参数，将docker-init作为容器内1号进程，帮助管理子进程

```bash
root@yuki:~# docker run -it --init busybox sh
/ # ps aux
PID   USER     TIME  COMMAND
    1 root      0:00 /sbin/docker-init -- sh
    7 root      0:00 sh
    8 root      0:00 ps aux
```

可以看到1号进程就是docker init



### docker-proxy

用来做端口映射，当使用了-p参数的时候就会使用到，底层依赖于iptables实现

启动一个容器，映射内部80端口到外部8080，并查看它的容器ip地址

```bash
root@yuki:~# docker run --rm --name=nginx -d -p 8080:80 nginx:1.23
6d0f89eb56b0fe14bb2fe1371ed53b15d25040e6ce508613f15b2d2e3cf84a2e
root@yuki:~# docker inspect --format '{{.NetworkSettings.IPAddress}}' nginx
172.17.0.5
```

可以看到容器ip地址是172.17.0.5

通过ps命令查看主机上是否有docker-proxy进程

```bash
root@yuki:~# ps aux | grep docker-proxy
root       74289  0.0  0.0 1148872 3728 ?        Sl   14:38   0:00 /usr/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 8080 -container-ip 172.17.0.5 -container-port 80
root       74294  0.0  0.0 1075140 3632 ?        Sl   14:38   0:00 /usr/bin/docker-proxy -proto tcp -host-ip :: -host-port 8080 -container-ip 172.17.0.5 -container-port 80
root       74855  0.0  0.0   6432   656 pts/13   R+   14:41   0:00 grep --color=auto docker-proxy
```

可以看到，docker创建了一个docker-proxy进程，将访问0.0.0.0:8080的流量转发到172.17.0.5:80

查看iptables的转发规则

```bash
root@yuki:~# iptables -L -nv -t nat
Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    4  1680 DOCKER     all  --  *      *       0.0.0.0/0            0.0.0.0/0            ADDRTYPE match dst-type LOCAL

Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 DOCKER     all  --  *      *       0.0.0.0/0           !127.0.0.0/8          ADDRTYPE match dst-type LOCAL

Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MASQUERADE  tcp  --  *      *       172.17.0.5           172.17.0.5           tcp dpt:80

Chain DOCKER (2 references)
    0     0 DNAT       tcp  --  !docker0 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8080 to:172.17.0.5:80
```

通过最后一行也可以得知将访问0.0.0.0:8080的流量转发到172.17.0.5:80



## containerd

### containerd

从1.11版本正式从dockerd中剥离，完全遵循OCI标准

功能：

* 镜像管理
* 接受dockerd的请求，调用runC启动容器
* 管理存储，网络相关资源



### containerd-shim

将containerd核正在的容器进程解耦，使用containerd-shim作为容器的父进程，实现重启containerd不影响已经启动的容器进程



### ctr

containerd-ctr，客户端，可以直接向containerd发请求



## runC

真正创建和运行容器的cli

> 实验：通过runc来运行一个容器

创建根目录rootfs，并导入busybox的镜像文件，将其解压到rootfs目录中

```bash
root@yuki:~/playground/devops/docker/runc-demo# docker export $(docker create busybox) -o busybox.tar && mkdir ./rootfs && tar -xf busybox.tar -C ./rootfs
```

生产runc配置文件

```bash
root@yuki:~/playground/devops/docker/runc-demo# runc spec
root@yuki:~/playground/devops/docker/runc-demo# cat ./config.json 
{
        "ociVersion": "1.0.2-dev",
        "process": {
                "terminal": true,
 ## ....ingore
```

运行runc

```bash
root@yuki:~/playground/devops/docker/runc-demo# runc run busybox
/ # 
```

新打开一个控制台，查看刚才启动的容器

```bash
root@yuki:~/playground/devops/docker# runc list
ID          PID         STATUS      BUNDLE                                     CREATED                          OWNER
busybox     77418       running     /root/playground/devops/docker/runc-demo   2023-03-17T15:07:23.005486397Z   root
```





# Docker网络

Docker定义的网络模型标准是CNM(Container Network Model)，只要满足CNM接口的网络方案都可以接入Docker容器网络，有以下3个组成元素：Sandbox，EndPoint，Network



## CNM

Docker定义的网络模型标准是CNM(Container Network Model)，但是最终kubernetes选择了CNI....



### Sandbox

沙箱，代表了一些列的网络堆栈的配置，包含路由信息，网络接口等网络资源管理。一般是基于net namespace实现，但也可以有其它实现方式



### EndPoint

接入点，代表容器的网络接口，通常实现是Linux的veth设备对



### Network

一组可以互相通信endpoint，可以将多个endpoint组成一个子网，多个endpoint之间可以互相通信



## Libnetwork

CNM的Docker官方实现，通过插件的形式为Docker提供网络功能，通过Go实现，[地址仓库](https://github.com/moby/libnetwork)，[文档地址](https://pkg.go.dev/github.com/docker/libnetwork)

工作流程大致如下：

![image-20230320151420791](image-20230320151420791.png)

## 网络模式

### 空网络模式

容器没有创建任何网卡接口，IP地址和路由等网络配置

```bash
$ docker run --net=none -it busybox
# 查看容器内网络配置信息
/ # ifconfig
lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
# 查看容器内路由
/ # route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
/ # exit
```

可以看到，容器内没有配置出了lo网卡以外的其它网卡，也没有配置任何路由信息



### bridge桥接模式

默认使用该模式，通过该模式可以实现：

* 可以实现容器与容器之间网络互通，可以从一个容器直接通过容器IP访问另一个容器
* 可以实现主机与容器的互通，容器内启动的业务可以从主机直接请求

与bridge相关的技术

#### Linux veth

Linux中的虚拟设备接口，成对出现，可以用来连接虚拟网络设备，例如veth可以联通两个Net Namespace，从而让两个Net Namespace可以互相访问

#### Linux bridge

一个虚拟设备，用来连接网络的设备，可以转发两个Net Namespace内的traffic

> Docker启动时，libnetwork会在主机上创建docker0的Linux bridge，而bridge模式的容器都会连接到docker0的bridge上

veth与bridge的关系

![image-20230320153306524](image-20230320153306524.png)



### host主机网络模式

当业务需要容器去创建或者更新主机的网络模式的时候，需要使用host主机网络模式

使用host模式的时候，libnetwork不会创建新的网络配置和Net Namaspace，容器中的进程直接共享主机网络配置，可以直接使用主机网络信息，但是其它的内容（如进程，文件系统，主机名等）都是与主机隔离的

```bash
$ docker run --rm --net=host -it busybox
/ # ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel qlen 1000
    link/ether 00:0c:29:07:19:69 brd ff:ff:ff:ff:ff:ff
    inet 192.168.31.233/24 brd 192.168.31.255 scope global ens33
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:fe07:1969/64 scope link 
       valid_lft forever preferred_lft forever
3: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue 
    link/ether 02:42:e1:e2:5b:47 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:e1ff:fee2:5b47/64 scope link 
       valid_lft forever preferred_lft forever
# ignore rest inforatmio...
```

可以看到，ens33的ip地址和主机一直，且也拥有docker0网桥，整个输出与主机是完全一致的



### container网络模式

允许一个容器共享另一个容器的网络命名空间。当两个容器需要共享网络，但其它资源需要隔离时，可以使用该模式。两个容器之间需要通过localhost连接（如nginx容器为业务容器做代理的时候）可以考虑container模式





# Docker持久化

Docker针对持久化提出卷（Volume）的概念，本质是文件或者目录，可以绕过联合文件系统，直接以文件或者目录的形式存在于宿主机上。



## 命令



创建卷

```bash
$ docker volume create <your volume name>
```

查看卷

```bash
$ docker volume ls
$ docker volume inspect <your volume name>
```

删除卷

> 正在被使用中的volume无法删除

```bash
$ docker volume rm <your volume name>
```





容器中挂载卷

```bash
$ docker run -v /usr/share/nginx/html nginx
```

`-v`指令可以自动创建卷，并直接挂载到容器中的指定目录

使用一个已存在的卷（经docker volumecreate命令创建）

```bash
$ docker run --mount source=<your volume name>,target=<path in container> nginx
```

容器与主机指定目录共享数据

```bash
$ docker run -v <host path>:<container path> nginx
```



## 原理

卷的创建在主机的`/var/lib/docker/volumes`中，文件夹中包含所有的volume，每个子文件夹中的`_data`文件夹包含该volume的全部文件，如：

```bash
$ docker volume inspect compose-user-data
[
    {
        "CreatedAt": "2022-10-28T07:44:52Z",
        "Driver": "local",
        "Labels": {
            "com.docker.compose.project": "compose",
            "com.docker.compose.version": "2.6.0",
            "com.docker.compose.volume": "user_data"
        },
        "Mountpoint": "/var/lib/docker/volumes/compose-user-data/_data",
        "Name": "compose-user-data",
        "Options": null,
        "Scope": "local"
    }
]
$ ls -l /var/lib/docker/volumes/compose-user-data/_data/
total 4
-rw-r--r-- 1 root root 36 Oct 28 07:44 user.json
```



# 联合文件系统

Union File System，Unionfs，是一种分层的轻量级文件系统，它可以把多个目录内容联合挂载到同一目录下，形成单一的文件系统。

联合文件系统是Docker镜像和容器的基础，镜像的每一层都可以被共享。例如两个镜像都是基于ubuntu20.04镜像创建的，那么我们存储的时候仅需要存一个底层ubuntu20.04镜像，而不需要存两个。

常用的联合文件系统有：

* AUFS

* Devicemapper

* OverlayFS

  主流采用

##  OverlayFS

>  推荐生产环境中使用的是overlay2
>
>  overlay2将镜像层和容器层都放在单独的目录中，并有唯一ID，每一层进存储发生变化的文件，最后使用联合挂载技术将容器和镜像层的所有文件统一挂载到容器中，使得容器看到完整的文件系统

### 基本概念

* overlay2将所有目录成为layer（层）
* 将layer统一展现到一个目录下的过程成为联合挂载
* 把目录的下一层称为lowerdir，上一层成为upperdir，联合挂载的结果叫merged

docker中overlay2的路径是`var/lib/docker/overlay2`，该路径下包含两类内容：

* 镜像层与容器层的目录

  ```bash
  $ ls -al /var/lib/docker/overlay2/c090f1ecdbfe9c580747181aa8092a5ed3f6ff086e268310f27d4dfeaff9ef18
  total 60
  drwx--x---   5 root root  4096 Mar 16 08:15 .
  drwx--x--- 249 root root 32768 Mar 20 07:59 ..
  drwxr-xr-x   5 root root  4096 Mar 16 08:15 diff
  -rw-r--r--   1 root root    26 Mar 16 08:15 link
  -rw-r--r--   1 root root   347 Mar 16 08:15 lower
  drwxr-xr-x   1 root root  4096 Mar 16 08:15 merged
  drwx------   3 root root  4096 Mar 16 08:15 work
  ```

  diff：镜像层或容器层的改动内容

  link：镜像层或容器层的短id

  lower：镜像层或容器层的父层的所有镜像的短id

  merge：分层文件联合挂载的结果，也是容器内的工作目录

  

* `var/lib/docker/overlay2/l`

  本质是一堆由镜像的短id名称构成的软连接，连接的目的是镜像的diff文件夹，是为了避开mount命令参数的长度限制

  ```bash
  $ ls -al /var/lib/docker/overlay2/l/
  total 976
  drwx------   2 root root 16384 Mar 20 07:59 .
  drwx--x--- 249 root root 32768 Mar 20 07:59 ..
  lrwxrwxrwx   1 root root    72 Aug  9  2022 27TVCGAWXKFRSE2BZMTHH7CBFB -> ../10c2441eeaa73c21b105be4ffc977a6150f907431c07134a0b04abf84488ac75/diff
  lrwxrwxrwx   1 root root    72 Aug  9  2022 2BL7BZB3GAQ36JRK3GNBCULAQP -> ../fd6befa5579ef7ef828135a530f25026aec57fdbe0c2f4ddae52570a0610e94a/diff
  lrwxrwxrwx   1 root root    72 Mar  3 09:49 2EU2YUIQ2QIMQTP3AYGMIOTUFV -> ../31af82b9b7b8c23d57013ebc0248fb281713cba19e7880c2e265fc8773ac466c/diff
  ```



#### 查看层级关系的命令

通过docker命令查看镜像的层级关系

```bash
$ docker image inspect mysql:8
[
    {
        "Id": "sha256:4073e6a6f54214da05256022b9a86e2f3f480703d1fc457a7085107c854e5ce3",
        "RepoTags": [
            "mysql:8"
        ],
 # ignore....  
        "GraphDriver": {
            "Data": {
                "LowerDir": "/var/lib/docker/overlay2/a2ca74f1f4ff597cc57852249b2f17de3c2cf9f272629907b76b883f690bad06/diff:/var/lib/docker/overlay2/7e7ad66ed2cd94ef47b80650bc4f2bb3649e156ea578d7c61b41cb8d4b9566c4/diff:/var/lib/docker/overlay2/facade5231f2e91aaa2ec5c1da4489696e66a2d8f0c607c2cce9a95f3ba5afe0/diff:/var/lib/docker/overlay2/baf919e79a2e081b8ea54be77127fbfbab28fd04cd64df875107d3b2327bd8d0/diff:/var/lib/docker/overlay2/d4162ebff3ecd06f2467ecef607bc6b4ee821ffc879353e6f30fed42e8630b85/diff:/var/lib/docker/overlay2/27ff95a85b08dfbc2f853bb551885c9f7215edca9b156ef0178302968c1f4663/diff:/var/lib/docker/overlay2/fbcd6812563b341bd12f1427963f5a7634b16cb554ddeb538db5d6b965213d5b/diff:/var/lib/docker/overlay2/e93e517bcc8aa3628892806add5dde0abae7a87069e6256f8f5937df621ace5e/diff:/var/lib/docker/overlay2/65c79daea2bf3e01444c340748e6f2255430d4ec1cb49cd1417ed15f09a82dc2/diff:/var/lib/docker/overlay2/1140eeeba6ee24a0335e432fb91a7f007114d962f5c4123110e957e956387118/diff",
                "MergedDir": "/var/lib/docker/overlay2/d63e11caa181f7dc6ecd9fd97e4a0729fe575eff9011a9ea5f637782ce76e220/merged",
                "UpperDir": "/var/lib/docker/overlay2/d63e11caa181f7dc6ecd9fd97e4a0729fe575eff9011a9ea5f637782ce76e220/diff",
                "WorkDir": "/var/lib/docker/overlay2/d63e11caa181f7dc6ecd9fd97e4a0729fe575eff9011a9ea5f637782ce76e220/work"
            },
            "Name": "overlay2"
        },
 # ignore....  
    }
]
```

其中，`GraphDriver.Data.LowerDir`记录的是所有父级镜像层的层级，用冒号隔开，最后一个层级表示最底层



通过docker命令查看容器的工作目录

```bash
$ docker inspect mysql
[
    {
        "Id": "dd062a0f7ece3d977f94962e683cc9fba051bd48fcca9a8125352914be6cf9e8",
        "Created": "2023-03-16T08:15:12.63675004Z",
 # ignore....       
        "GraphDriver": {
            "Data": {
                "LowerDir": "/var/lib/docker/overlay2/c090f1ecdbfe9c580747181aa8092a5ed3f6ff086e268310f27d4dfeaff9ef18-init/diff:/var/lib/docker/overlay2/d63e11caa181f7dc6ecd9fd97e4a0729fe575eff9011a9ea5f637782ce76e220/diff:/var/lib/docker/overlay2/a2ca74f1f4ff597cc57852249b2f17de3c2cf9f272629907b76b883f690bad06/diff:/var/lib/docker/overlay2/7e7ad66ed2cd94ef47b80650bc4f2bb3649e156ea578d7c61b41cb8d4b9566c4/diff:/var/lib/docker/overlay2/facade5231f2e91aaa2ec5c1da4489696e66a2d8f0c607c2cce9a95f3ba5afe0/diff:/var/lib/docker/overlay2/baf919e79a2e081b8ea54be77127fbfbab28fd04cd64df875107d3b2327bd8d0/diff:/var/lib/docker/overlay2/d4162ebff3ecd06f2467ecef607bc6b4ee821ffc879353e6f30fed42e8630b85/diff:/var/lib/docker/overlay2/27ff95a85b08dfbc2f853bb551885c9f7215edca9b156ef0178302968c1f4663/diff:/var/lib/docker/overlay2/fbcd6812563b341bd12f1427963f5a7634b16cb554ddeb538db5d6b965213d5b/diff:/var/lib/docker/overlay2/e93e517bcc8aa3628892806add5dde0abae7a87069e6256f8f5937df621ace5e/diff:/var/lib/docker/overlay2/65c79daea2bf3e01444c340748e6f2255430d4ec1cb49cd1417ed15f09a82dc2/diff:/var/lib/docker/overlay2/1140eeeba6ee24a0335e432fb91a7f007114d962f5c4123110e957e956387118/diff",
                "MergedDir": "/var/lib/docker/overlay2/c090f1ecdbfe9c580747181aa8092a5ed3f6ff086e268310f27d4dfeaff9ef18/merged",
                "UpperDir": "/var/lib/docker/overlay2/c090f1ecdbfe9c580747181aa8092a5ed3f6ff086e268310f27d4dfeaff9ef18/diff",
                "WorkDir": "/var/lib/docker/overlay2/c090f1ecdbfe9c580747181aa8092a5ed3f6ff086e268310f27d4dfeaff9ef18/work"
            },
            "Name": "overlay2"
        },
 # ignore....
    }
]
```

其中，`GraphDriver.Data.LowerDir`记录的是所有父级镜像层的层级，用冒号隔开，最后一个层级表示最底层，我们可以看到上面对应的mysql:8的镜像中的LowerDir的层级均存在与本容器工作目录的LowerDir中



### 修改文件或者目录过程

#### 首次修改

overlay2触发写时复制，首先将镜像层文件复制到容器层，然后容器层执行对应的文件修改

#### 删除文件或目录

overlay2创建一个特殊的文件或目录，这种文件或目录会阻止容器的访问



# 实现Docker



## Linux Proc

`/proc`存放与内存中，是一个虚拟的文件系统，该目录存放了当前内核运行状态的一系列的特殊文件

```bash
$ sudo ls -al /proc
total 4
dr-xr-xr-x 355 root             root                           0 Mar  9 07:41 .
drwxr-xr-x  19 root             root                        4096 Aug  1  2022 ..
dr-xr-xr-x   9 root             root                           0 Mar  9 07:41 1
dr-xr-xr-x   9 root             root                           0 Mar 20 09:23 10
# ignore...
dr-xr-xr-x   9 root             root                           0 Mar 20 09:23 596722
# ignore...
lrwxrwxrwx   1 root             root                           0 Mar  9 07:41 self -> 596722
```

* self

  连接到当前正在运行的进程目录

* `/proc/{PID}/exe`

  连接到进程执行的命令文件



