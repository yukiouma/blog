---
title: Docker Compose Getting Start
date: 2022-03-15 22:17:35
tags: 
- Docker
categories:
- DevOps
---

# 准备工作

假设有两个服务：

* `greeting`

  > 本服务依赖于`fibo`服务，因此，服务启动前会尝试获取环境变量中的`fiboaddr`的值来获取`fibo`服务的地址，并尝试调用`fibo`服务的接口，成功后才会继续启动

  路由：

  * `/`：返回一个hello
  * `/user`：返回容器中`data/user.json`路径下的`json`数据，该数据需要持久化到宿主机中
  * `/fibo?num={number}`：调用`fibo`服务中的`fibo`接口并返回结果

  <!-- more -->

  镜像：

  `playground:5000/compose-greeter:v1`

* `fibo`

  > 仅面对greeting服务开放调用，不对外开放调用

  路由：

  * `/fibo?num={number}`：计算斐波那契数列中某一下表的值

  镜像：

  `playground:5000/compose-fibo:v1`



# compose spec

启动准备工作中的两个相关联的服务，我们使用以下的`docker-compose.yaml`

```yaml
version: '3.0'
services:
  svc-fibo:
    container_name: fibo
    image: playgrouond:5000/compose-fibo:v1
    expose:
      - 8081
    command: [ "./server", "-port", "8081" ]
    restart: always
    networks:
      - compose-svc
  svc-greeting:
    container_name: greeter
    image: playgrouond:5000/compose-greeter:v1
    ports:
      - 9000:8080
    command: [ "./server", "-port", "8080" ]
    volumes:
      - user_data:/home/data
    environment:
      - fiboaddr=svc-fibo:8081
    restart: always
    networks:
      - compose-svc
    depends_on:
      - svc-fibo
volumes:
  user_data:
    name: compose-user-data
    driver: local
networks:
  compose-svc:
    name: compose-svc-yuki
    driver: bridge
```

下面我们来对文件中的常用配置进行说明



## 骨架

```yaml
version: '3.9'
services:

  svc-fibo:

  svc-greeting:

volumes:

networks:

```

文件中的骨架主要是这些内容：

* version：docker compose文件格式的版本，与docker版本的关系参考[Compose和Dokcer兼容性表格](https://docs.docker.com/compose/compose-file/compose-file-v3/#compose-and-docker-compatibility-matrix)

* services

  列举compose里面要启动的服务的配置，如上述要启动`svc-fibo`和`svc-greeting`两个服务，因此在services里面要包含`svc-fibo`和`svc-greeting`两个对象

* volumes

  持久化配置

* networks

  定义该组容器的网络配置。

接下来针对version外的每部分内容进行说明：



## services

在services对象中每个服务一个独立的对象，对象中包含以下信息：



### container_name

```yaml
container_name: fibo
```

容器启动后的名称。如上面的svc-fibo服务中的该字段的值是fibo，那么容器的名称则为fibo



### image:

镜像名称



### expose

```yaml
expose:
	- 8081
```

在当前网络中，开放给其它容器可见的端口，但是不会暴露给宿主机。

他其实只是一个声明，把它去掉了，同一网络下的容器其实依然能正常请求到某个端口的服务



### ports

绑定容器与宿主机的端口

```yaml
ports:
	- 9000:8080
```

`宿主机端口:容器端口`，上面表示宿主机端口9000映射到容器端口8080

````bash
$ docker logs greeter
2022/10/28 07:16:07 listening port 8080....
2022/10/28 07:16:15 - method: GET; path: /fibo; param: map[]
2022/10/28 07:16:21 - method: GET; path: /fibo; param: map[num:[10]]
$ curl http://localhost:9000/fibo?num=10
{"data":55}
````

可以到容器内部的日志提示监听的端口是8080，但我们是通过宿主机的9000端口访问到具体服务



### environment

设置容器运行时的环境变量

```bash
environment:
	- fiboaddr=svc-fibo:8081
```

如上面的内容指在容器中注入一个值为`svc-fibo:8081`的环境变量`fiboaddr`，我们可以进入对应容器中验证该环境变量的存在

```bash
$ docker exec -it greeter /bin/sh
/home # echo $fiboaddr
svc-fibo:8081
/home # exit
```

可以看到打印的环境变量`fiboaddr`的值和在配置文件中保持一致



### restart

```yaml
restart: always
```

重启策略，默认是no，表示不主动重启容器，例子中表示容器被退出与销毁会一直尝试重启，其它信息查看[重启策略](https://docs.docker.com/compose/compose-file/#restart)



### command

```yaml
command: [ "./server", "-port", "8080" ]
```

容器启动时执行的指令，会覆盖Dockerfile中的CMD指令。上面表示容器启动的时候会在当前路径下执行：

```bash
$ ./server -port 8080
```



### depends_on

表示容器启动要依赖于其它的容器的存在，即在depends on列表里面的容器启动成功后，本容器才会被启动

```yaml
depends_on:
  - svc-fibo
```
表示容器`svc-fibo`启动后本容器才会去启动



### volumes

容器中的目录映射到宿主机的目录中，可以将容器内的数据持久化到宿主机中或者其它存储空间。大致分为两种写法：

* 直接指定容器中的路径去映射宿主机的路径

  ```yaml
  volumes:
  	- /var/lib/data:/home/data
  ```

  代表容器中的路径`/home/data`映射到宿主机中的路径`/var/lib/data`

* 指定

  ```yaml
  services:
    svc-fibo:
      volumes:
        - user_data:/home/data
  volumes:
    user_data:
      name: compose-user-data
      driver: local
  ```

  代表容器中的路径`/home/data`映射到顶部volume层定义的`user_data`对象

  查看docker中是否存在该volume

  ```bash
  $  docker volume ls -f name=compose-user-data
  DRIVER    VOLUME NAME
  local     compose-user-data
  ```



### networks

指定容器使用顶部networks层定义的网络

```yaml
services:
  svc-fibo:
    networks:
      - compose-svc
networks:
  compose-svc:
    name: compose-svc-yuki
    driver: bridge
```

指定容器使用顶部networks层定义的网络`compose-svc`



## volume

定义容器存储对象，用于映射容器内部的路径，持久化容器内部的数据

通过本方式创建的存储对象在宿主机的位置是`/var/lib/docker/volumes/{volume_name}/_data/`

```yaml
volumes:
  user_data:
    name: compose-user-data
    driver: local
```

上面的内容指定了存储对象的名字与驱动，可以通过以下方式查看

```bash
$ docker volume ls
DRIVER    VOLUME NAME
local     compose-user-data
```

对应到宿主机的位置则是：

```bash
$ pwd
/var/lib/docker/volumes/compose-user-data/_data
```

如果我们没有指定名字，那么会为我们自动创建的名字是`当前文件夹名称+对象名称`，假设我们当前docker-compose.yaml处于的目录名称是compose，那么自动创建的名字则是`compose_user_data`

容器在绑定volume后可以直接读取于写入`/var/lib/docker/volumes/{volume_name}/_data/`中的数据

在services层的容器定义中使用时需要指定的是对象的名字而不是volume本身的名字

```yaml
services:
  svc-fibo:
    volumes:
      - user_data:/home/data # 是user_data而不是compose-user-data
```





## networks

定义docker网络，在同一个网络下的容器之间可以相互通信

```yaml
networks:
  compose-svc:
    name: compose-svc-yuki
    driver: bridge
```

如果我们没有指定名字，那么会为我们自动创建的名字是`当前文件夹名称+default`，假设我们当前docker-compose.yaml处于的目录名称是compose，那么自动创建的名字则是`compose_default`

在services层的容器定义中使用时需要指定的是对象的名字而不是network本身的名字

```yaml
    networks:
      - compose-svc # 是compose-svc而不是compose-svc-yuki
```



# 启动与关闭

```bash
$ docker compose up -d
[+] Running 4/4
 ⠿ Network compose-svc-yuki    Created                                                    0.1s
 ⠿ Volume "compose-user-data"  Created                                                    0.0s
 ⠿ Container fibo              Started                                                    0.5s
 ⠿ Container greeter           Started                                                    0.8s
```

查看当前compose中的容器：

```bash
$  docker compose ps
NAME                COMMAND                 SERVICE             STATUS              PORTS
fibo                "./server -port 8081"   svc-fibo            running             8081/tcp
greeter             "./server -port 8080"   svc-greeting        running             0.0.0.0:9000->8080/tcp, :::9000->8080/tcp
```

尝试向greeter容器发送请求

```bash
$ curl http://localhost:9000/fibo?num=10
{"data":55}
```

查看两个容器中的日志

```bash
$ docker logs greeter
2022/10/28 08:28:18 listening port 8080....
2022/10/28 08:28:48 - method: GET; path: /fibo; param: map[num:[10]]

$ docker logs fibo
2022/10/28 08:28:17 listening port 8081....
2022/10/28 08:28:18 - method: GET; path: /fibo; param: map[num:[1]]
2022/10/28 08:28:48 - method: GET; path: /fibo; param: map[num:[10]]
```

可以看到，运行正常，部署完成

我们可以通过以下命令将compose中定义的容器全部关闭

```bash
$ docker compose down
[+] Running 3/3
 ⠿ Container greeter         Removed                                                      0.3s
 ⠿ Container fibo            Removed                                                      0.2s
 ⠿ Network compose-svc-yuki  Removed                                                      0.1s
```

