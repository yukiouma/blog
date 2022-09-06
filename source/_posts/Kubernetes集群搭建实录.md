---
title: Kubernetes集群搭建实录
date: 2021-06-05 15:01:25
tags: 
- Kubernetes
categories:
- 服务器运维
---

# Kubernetes集群搭建实录



## 环境与配置

* VMware® Workstation 15 Pro - 15.5.0 build-14665864
* 宿主机： Windows 10, 64-bit  (Build 19042) 10.0.19042
* CentOS Linux release 7.9.2009 (Core)



## 资源清单

* docker-ce-18.06.3.ce-3.el7
* kubeadm-1.17.4-0
* kubelet-1.17.4-0
* kubectl-1.17.4-0
* flannel:v0.14.0
* metrics-server v0.3.6

<!-- more -->

## 步骤



### 创建虚拟机

配置为CPU2核，内存2G，磁盘100G，网络选用NAT模式



### 固定虚拟机IP

```shell
vi /etc/sysconfig/network-scripts/ifcfg-env33
```

```shell
BOOTPROTO="static"	# 将虚拟机的地址获取改为静态
ONBOOT="yes"		# 
IPADDR=192.168.1.210	# 前三段与VMnet8的ip中的第三段保持一致，第四段为自定义
GATEWAY=192.168.1.2		# 与VMnet8的gateway保持一致
NETMASK=255.255.255.0
DNS1=8.8.8.8i
```
配置域名解析

 ```shell
vi /etc/resolv.conf
 ```

```shell
nameserver 8.8.8.8
```

生效配置

```shell
service network restart
```



###  关闭与禁用防火墙 

```shell
 关闭防火墙
systemctl stop firewalld
 禁用防火墙
systemctl disable firewalld
```

关闭` Selinux `

```shell
vi /etc/selinux/config
```

```shell
SELINUX=disabled
```



### 配置自定义域名解析

```shell
vi /etc/hosts
```

```shell
192.168.1.210 k8smaster
192.168.1.211 k8sworker1
192.168.1.212 k8sworker2
```



### 禁用swap分区

```shell
vi /etc/fstab
```

注释掉该行

```shell
#/dev/mapper/centos-swap swap                    swap    defaults        0 0
```



### 修改内核参数

```shell
vi /etc/sysctl.d/kubernetes.conf
```

```shell
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
```

重新加载配置

```shell
sysctl -p
```

加载网桥过滤模块

```shell
modprobe br_netfilter
```

查看网桥过滤模块是否成功加载

```shell
lsmod | grep br_netfilter
```





### 更换yum镜像源

安装wget

```shell
yum install -y wget
```

备份原有的yum源

```shell
mv /etc/yum.repos.d/CentOS-Base.repo 	 /etc/yum.repos.d/CentOS-Base.repo.backup
```

安装阿里源

```shell
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
```

清理旧缓存并生成新缓存

```shell
yum clean all
yum makecache
```

升级yun

```shell
yum update -y
```





### 安装chrony

chrony是用于将本机时间与网络同步的软件

```shell
yum install -y chrony
```

 启动服务

```shell
systemctl start chronyd
systemctl enable chronyd
```



### 配置ipvs

```shell
yum install ipset ipvsadm -y
```

添加需要加载的模块写入脚本文件

```shell
cat <<EOF > /etc/sysconfig/modules/ipvs.modules
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
```

为脚本文件添加执行权限

```shell
chmod +x /etc/sysconfig/modules/ipvs.modules
```

执行

```shell
/bin/bash /etc/sysconfig/modules/ipvs.modules
```

查看对应模块是否加载成功

```shell
lsmod | grep -e ip_vs -e nf_conntrack_ipv4
```



### 克隆虚拟机

克隆按照上述配置的虚拟机两台，分别锁定ip为192.168.1.211和192.168.1.212，这两台将作为子节点



### 安装docker

> 此步骤需要三台虚拟机同时执行
>
> 本次安装的docker版本为18.06.3-ce，配合上面安装的Kubernetes组件1.17.4版本，如果选用最新版的docker可能会报版本未经校验的错误

移除系统残留的docker相关内容

```shell
yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
```

添加yum源

```shell
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```

安装docker，启动并设置开机自启动

```shell
yum install --setopt=obsoletes=0 docker-ce-18.06.3.ce-3.el7 -y
systemctl start docker
systemctl enable docker
```





### 安装kubernetes组件

> 此步骤需要三台虚拟机同时执行

更新yum源

```shell
vi /etc/yum.repos.d/kubernetes.repo
```

```shell
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
       http://mirrors.aliyun.com/kubernetes/rpm-package-key.gpg
```

安装kubeadm，kubelet，kubectl

```shell
yum install --setopt=obsoletes=0 kubeadm-1.17.4-0 kubelet-1.17.4-0 kubectl-1.17.4-0 -y
```

配置kubelet的cgroup

```shell
vi /etc/sysconfig/kubelet
```

```shell
KUBELET_CGROUP_ARGS="--cgroup-driver=systemd"
KUBE_PROXY_MODE="ipvs"
```

设置kubelet开机自启动

```shell
systemctl enable kubelet
```



### 安装kubernetes镜像集群

注意，国内无法访问官方的镜像仓库，需要使用阿里的镜像仓库，下载后将内容标签更改为官方仓库的镜像的标签

```shell
vi ~/pull.sh
```

```shell
images=(
  kube-apiserver:v1.17.4
  kube-controller-manager:v1.17.4
  kube-scheduler:v1.17.4
  kube-proxy:v1.17.4
  pause:3.1
  etcd:3.4.3-0
  coredns:1.6.5
)

for i in ${images[@]}; do 
  imageName=${i#k8s.gcr.io/}
  docker pull registry.aliyuncs.com/google_containers/$imageName
  docker tag registry.aliyuncs.com/google_containers/$imageName k8s.gcr.io/$imageName
  docker rmi registry.aliyuncs.com/google_containers/$imageName
done;
```

执行下载镜像的脚本

```shell
sh ~/pull.sh
```



### 集群初始化

#### master

在master节点上执行：

```shell
kubeadm init --kubernetes-version=v1.17.4 --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/12 --apiserver-advertise-address=192.168.1.210
```



看到以下内容时说明安装成功：

```shell
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.1.210:6443 --token ltbp0b.ytq5v8tpgwlbmrah \
	--discovery-token-ca-cert-hash sha256:afe539eb3fbf77fa066f085fb49ed68dbb750b85ad7a3636d0d01532bd94d093 
```



安装完成后，执行以下命令

```shell
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```



#### node

在node节点上执行以下命令：

```shell
kubeadm join 192.168.1.210:6443 --token ltbp0b.ytq5v8tpgwlbmrah \
	--discovery-token-ca-cert-hash sha256:afe539eb3fbf77fa066f085fb49ed68dbb750b85ad7a3636d0d01532bd94d093
```

执行完毕后，node节点便加入master中

此时在master节点查看所有节点会看到两个worker已经加入master

```shell
[root@k8smaster ~]# kubectl get nodes
NAME         STATUS     ROLES    AGE     VERSION
k8smaster    NotReady   master   4m27s   v1.17.4
k8sworker1   NotReady   <none>   7s      v1.17.4
k8sworker2   NotReady   <none>   7s      v1.17.4
```



### 安装网络插件kube-flannel

> 本操作仅需在master节点上执行

创建文件`kube-flannel.yaml`

编辑写入以下内容：

```yaml
---
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: psp.flannel.unprivileged
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: docker/default
    seccomp.security.alpha.kubernetes.io/defaultProfileName: docker/default
    apparmor.security.beta.kubernetes.io/allowedProfileNames: runtime/default
    apparmor.security.beta.kubernetes.io/defaultProfileName: runtime/default
spec:
  privileged: false
  volumes:
  - configMap
  - secret
  - emptyDir
  - hostPath
  allowedHostPaths:
  - pathPrefix: "/etc/cni/net.d"
  - pathPrefix: "/etc/kube-flannel"
  - pathPrefix: "/run/flannel"
  readOnlyRootFilesystem: false
  # Users and groups
  runAsUser:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  # Privilege Escalation
  allowPrivilegeEscalation: false
  defaultAllowPrivilegeEscalation: false
  # Capabilities
  allowedCapabilities: ['NET_ADMIN', 'NET_RAW']
  defaultAddCapabilities: []
  requiredDropCapabilities: []
  # Host namespaces
  hostPID: false
  hostIPC: false
  hostNetwork: true
  hostPorts:
  - min: 0
    max: 65535
  # SELinux
  seLinux:
    # SELinux is unused in CaaSP
    rule: 'RunAsAny'
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: flannel
rules:
- apiGroups: ['extensions']
  resources: ['podsecuritypolicies']
  verbs: ['use']
  resourceNames: ['psp.flannel.unprivileged']
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - nodes/status
  verbs:
  - patch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: flannel
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flannel
subjects:
- kind: ServiceAccount
  name: flannel
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flannel
  namespace: kube-system
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: kube-flannel-cfg
  namespace: kube-system
  labels:
    tier: node
    app: flannel
data:
  cni-conf.json: |
    {
      "name": "cbr0",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan"
      }
    }
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-flannel-ds
  namespace: kube-system
  labels:
    tier: node
    app: flannel
spec:
  selector:
    matchLabels:
      app: flannel
  template:
    metadata:
      labels:
        tier: node
        app: flannel
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/os
                operator: In
                values:
                - linux
      hostNetwork: true
      priorityClassName: system-node-critical
      tolerations:
      - operator: Exists
        effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
      - name: install-cni
        image: quay.io/coreos/flannel:v0.14.0
        command:
        - cp
        args:
        - -f
        - /etc/kube-flannel/cni-conf.json
        - /etc/cni/net.d/10-flannel.conflist
        volumeMounts:
        - name: cni
          mountPath: /etc/cni/net.d
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      containers:
      - name: kube-flannel
        image: quay.io/coreos/flannel:v0.14.0
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: false
          capabilities:
            add: ["NET_ADMIN", "NET_RAW"]
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: run
          mountPath: /run/flannel
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      volumes:
      - name: run
        hostPath:
          path: /run/flannel
      - name: cni
        hostPath:
          path: /etc/cni/net.d
      - name: flannel-cfg
        configMap:
          name: kube-flannel-cfg
```

执行以下命令：

```shell
kubectl apply -f kube-flannel.yaml
```

一分钟左右之后，查看集群节点状态：

```shell
[root@k8smaster ~]# kubectl get nodes
NAME         STATUS   ROLES    AGE     VERSION
k8smaster    Ready    master   13m     v1.17.4
k8sworker1   Ready    <none>   8m41s   v1.17.4
k8sworker2   Ready    <none>   8m41s   v1.17.4
```

可以看到，三个节点的状态都是ready了



### 安装HPA

安装Horizontal Pod Autoscaler(HPA)，用于管理pods的弹性伸缩的组件

克隆组件仓库

```shell
git clone -b v0.3.6 https://github.com/kubernetes-sigs/metrics-server.git
```

修改`metrics-server/deploy/1.8+/metrics-server-deployment.yaml`为以下内容：

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metrics-server
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-server
  namespace: kube-system
  labels:
    k8s-app: metrics-server
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  template:
    metadata:
      name: metrics-server
      labels:
        k8s-app: metrics-server
    spec:
      hostNetwork: true
      serviceAccountName: metrics-server
      volumes:
      # mount in tmp so we can safely use from-scratch images and/or read-only containers
      - name: tmp-dir
        emptyDir: {}
      containers:
      - name: metrics-server
        image: registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server-amd64:v0.3.6
        imagePullPolicy: Always
        args:
          - --kubelet-insecure-tls
          - --kubelet-preferred-address-types=InternalIP,Hostname,InternalDNS,ExternalDNS,ExternalIP
        volumeMounts:
        - name: tmp-dir
          mountPath: /tmp
```

部署

```shell
cd ~/metrics-server/deploy/1.8+
kubectl apply -f ./
```

测试是否安装成功（安装完稍等几分钟等待数据同步）

```shell
kubectl top nodes
```

若能正常显示资源占用情况，即安装成功

```shell
[root@k8smaster 1.8+]# kubectl top nodes
NAME         CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
k8smaster    128m         6%     1037Mi          60%       
k8sworker1   44m          2%     591Mi           34%       
k8sworker2   51m          2%     595Mi           34% 
```



### 安装Ingress-Nginx

ingress-nginx是kubernetes做反向代理的一个组件

创建一个文件夹，并进入：

```shell
mkdir ~/ingress-nginx
cd ~/ingress-nginx
```

在该文件夹下创建两个文件：

mandatory.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx

---

kind: ConfigMap
apiVersion: v1
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx

---
kind: ConfigMap
apiVersion: v1
metadata:
  name: tcp-services
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx

---
kind: ConfigMap
apiVersion: v1
metadata:
  name: udp-services
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nginx-ingress-serviceaccount
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx

---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: nginx-ingress-clusterrole
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
rules:
  - apiGroups:
      - ""
    resources:
      - configmaps
      - endpoints
      - nodes
      - pods
      - secrets
    verbs:
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - services
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - events
    verbs:
      - create
      - patch
  - apiGroups:
      - "extensions"
      - "networking.k8s.io"
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - "extensions"
      - "networking.k8s.io"
    resources:
      - ingresses/status
    verbs:
      - update

---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: Role
metadata:
  name: nginx-ingress-role
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
rules:
  - apiGroups:
      - ""
    resources:
      - configmaps
      - pods
      - secrets
      - namespaces
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - configmaps
    resourceNames:
      # Defaults to "<election-id>-<ingress-class>"
      # Here: "<ingress-controller-leader>-<nginx>"
      # This has to be adapted if you change either parameter
      # when launching the nginx-ingress-controller.
      - "ingress-controller-leader-nginx"
    verbs:
      - get
      - update
  - apiGroups:
      - ""
    resources:
      - configmaps
    verbs:
      - create
  - apiGroups:
      - ""
    resources:
      - endpoints
    verbs:
      - get

---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: nginx-ingress-role-nisa-binding
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: nginx-ingress-role
subjects:
  - kind: ServiceAccount
    name: nginx-ingress-serviceaccount
    namespace: ingress-nginx

---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: nginx-ingress-clusterrole-nisa-binding
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: nginx-ingress-clusterrole
subjects:
  - kind: ServiceAccount
    name: nginx-ingress-serviceaccount
    namespace: ingress-nginx

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-ingress-controller
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/part-of: ingress-nginx
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ingress-nginx
        app.kubernetes.io/part-of: ingress-nginx
      annotations:
        prometheus.io/port: "10254"
        prometheus.io/scrape: "true"
    spec:
      # wait up to five minutes for the drain of connections
      terminationGracePeriodSeconds: 300
      serviceAccountName: nginx-ingress-serviceaccount
      nodeSelector:
        kubernetes.io/os: linux
      containers:
        - name: nginx-ingress-controller
          image: quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.30.0
          args:
            - /nginx-ingress-controller
            - --configmap=$(POD_NAMESPACE)/nginx-configuration
            - --tcp-services-configmap=$(POD_NAMESPACE)/tcp-services
            - --udp-services-configmap=$(POD_NAMESPACE)/udp-services
            - --publish-service=$(POD_NAMESPACE)/ingress-nginx
            - --annotations-prefix=nginx.ingress.kubernetes.io
          securityContext:
            allowPrivilegeEscalation: true
            capabilities:
              drop:
                - ALL
              add:
                - NET_BIND_SERVICE
            # www-data -> 101
            runAsUser: 101
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
            - name: https
              containerPort: 443
              protocol: TCP
          livenessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 10
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 10
          lifecycle:
            preStop:
              exec:
                command:
                  - /wait-shutdown

---

apiVersion: v1
kind: LimitRange
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  limits:
  - min:
      memory: 90Mi
      cpu: 100m
    type: Container
```

service-nodeport.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  type: NodePort
  ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
    - name: https
      port: 443
      targetPort: 443
      protocol: TCP
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx

---

```

执行两个配置文件

```shell
kubectl apply -f ./
```

查看对应的pod和service有没有创建成功

```shell
[root@k8smaster practice]# kubectl get pods -n ingress-nginxNAME                                        READY   STATUS    RESTARTS   AGE
nginx-ingress-controller-7f74f657bd-tcz5n   1/1     Running   0          78s

[root@k8smaster practice]# kubectl get svc -n ingress-nginx
NAME            TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx   NodePort   10.110.29.232   <none>        80:30930/TCP,443:31432/TCP   112s
```



自此，集群已经完全搭建完毕



## 测试集群

测试集群是否正常运行

在集群中部署一个Nginx服务



### 部署Nginx

```shell
[root@k8smaster ~]# kubectl create deployment nginx --image=nginx:1.14-alpine
deployment.apps/nginx created

[root@k8smaster ~]# kubectl get pods
NAME                     READY   STATUS    RESTARTS   AGE
nginx-65c4bffcb6-knp2d   1/1     Running   0          15s
```



### 暴露端口

```shell
[root@k8smaster ~]# kubectl expose deployment nginx --port=80 --type=NodePort
service/nginx exposed

[root@k8smaster ~]# kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP        41m
nginx        NodePort    10.103.157.11   <none>        80:31298/TCP   43s
```

其中nginx的port中的80:31298表示对集群外暴露的端口问31298



回到Windows宿主机，访问192.168.1.210:31298，如果可以获取到nginx的主页，则表示部署成功了

```bash
C:\Users\Yuki>curl 192.168.1.210:31298
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

