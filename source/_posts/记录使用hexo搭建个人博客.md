---
title: 记录使用hexo搭建个人博客
date: 2019-10-31 23:40:42
tags: 
- hexo
categories:
- 个人博客搭建
---



### 写在前面

本文仅是对自己使用hexo+next搭建博客的一些步骤和遇到的一些“坑”，整个搭建过程几乎都是参考了崔大大（公众号：进击的Coder）的[利用 GitHub 从零开始搭建一个博客]( https://mp.weixin.qq.com/s/qWMsCUjbmD1tocNEt23qVw )这篇文章，有兴趣的同学可以关注崔大的公众号进行阅读。本文对Node.js的安装，Git安装与环境变量的配置与Gitee账号申请等步骤不作叙述。

---


<!-- more -->
### 配置

* 系统：Win 10
* Git版本：
* Node.js版本：v12.13.0
* Hexo版本： v4.0.0 
*  NexTv版本：7.4.2 
* 部署位置：GItee

---



### 搭建步骤

#### 更改npm镜像源，使用cnpm

嘛....使用淘宝镜像主要的原因是晚上家里的网络使用npm下载的时候真的慢到令人发指....

```powershell
npm install -g cnpm --registry=https://registry.npm.taobao.org
```

安装成功后可以使用cnpm代替npm啦~



#### 全局安装Hexo框架

```powershell
cnpm i -g hexo-cli
```



#### 在目标文件夹下初始化一个Hexo项目（这里就假定我们的项目名称叫blog）

```powershell
hexo init blog
```

这里有个很蛋疼的情况，就是hexo默认是使用npm安装依赖的，所以碰到网速不好的时候可以在使用hexo把基本框架搭建起来后，手动使用cnpm安装依赖包



####  将 Hexo 编译生成 HTML 代码 

```powershell
hexo g
```

至此博客的基本框架就搭好了，可以使用```hexo s```启动本地服务，通过访问``` http://localhost:4000 ```来访问生产的博客了



#### 部署到Gitee

为啥选择了Gitee而木有选择大名鼎鼎的Github呢，其实就是想选个服务器在国内的....访问速度比较快，其实Gitee也就是Github的汉化版啦.....不用太纠结

1. 创建一个Repository，并配置好仓库地址啥的

2. 修改我们本地项目的根目录下的```_config.yml```（吐槽一下这个跟```xml```是啥关系....）

   ```yml
   # Site （这些是博客主页的一些静态显示内容，开心就好....）
   title: <你的博客的名字>
   subtitle: <你的博客的副标题>
   description:
   keywords:
   author: <作者>
   language: en
   timezone:
   
   # URL 这个位置很重要，请千万要记得配置，之前没有作配置导致css和js木有被正确识别，不知道是不是只有Gitee有这个问题，崔大的文章中使用的Github没有提这个
   url: <仓库地址，如https://gitee.com/xxxxx/blog/>
   root: <仓库地址的根目录，如/blog>
   
   # Deployment
   deploy:
     type: git
     repo: <仓库地址+.git，如https://gitee.com/xxxxx/blog.git>
   ```

3. 安装hexo的一个部署插件hexo-deployer-git

   ```powershell
   cnpm i hexo-deployer-git --save
   ```

4. 在根目录一个一键部署的脚本，```deploy.sh```

   ```shell
   hexo clean
   hexo generate
   hexo deploy
   ```

5. 执行部署脚本
   ```powershell
   sh deploy.sh
   ```
   
   若本计算机是第一次与Gitee进行连接的时候是需要提交用户名和密码的（如果配置了ssh就不用，但是我懒....），以后就可以被Gitee记住直连啦
   
7. 部署完成后，进入项目仓库，点击Service --> Gitee Pages --> Create即可完成部署，部署完成后可以根据部署页面的提示的url进入你的博客查看部署效果啦~

#### 修改主题与样式

觉得自带的样式不太喜欢....就可以更换一下自己喜欢的主题，本文还是使用崔大推荐的Next，熊猫风格很赞的说

1. 安装Next主题到项目文件夹theme中：

   在项目的根目录右键选择Git Bash，打开后输入

   ```git
   git clone https://github.com/theme-next/hexo-theme-next themes/next
   ```

   

2. 修改根目录下的```_config.yml```

   ```yml
   theme: next
   ```

   

3. 修改```theme\next```下的```_config.yml```

   ```yml
   scheme: Pisces
   ```

4. 上班修bug困了....明天接着填....



