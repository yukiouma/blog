---
title: Node版本管理工具nvm与Node镜像源管理工具nrm的安装与配置
date: 2019-11-09 22:21:36
tags: 
- Nodejs
categories:
- Web开发
---



### nvm安装与配置

* 安装

  1. Windows

     下载[nvm]( https://github.com/coreybutler/nvm-windows/releases )（下载nvm-setup.zip即可），下载完成后在本地解压，运行安装即可
<!-- more -->
  2. Unix类的系统

     我太懒了.....大家参考[官方说明](https://github.com/nvm-sh/nvm )吧 \_(:з)∠)\_，然后补充一个事情，就是```curl```和```wget```这两个最简单的安装方式我这边一直要么下载失败要么请求木有相应.....反正最后我是用git安装成功的QAQ.....

* 配置Node.js

  1. ```nvm list```

     会列出当前环境下已安装的Node.js的版本，版本号前带星号```*```即为当前使用版本

  2. ```nvm install <version>```

     安装指定的版本的Node.js

  3. ```nvm use <version>```

     指定当前环境下使用的Node.js的版本

### nrm安装与配置

* 安装

  ```shell
  npm i -g nrm
  ```

  

* 查看，更改镜像源

  1. 查看当前使用的镜像源（带```*```的为当前使用镜像）

     ```shell
     nrm ls
     ```

  2. 更改镜像源

     ```shell
     nrm use <registry> 
     ```

  3. 镜像源测速

     ```shell
     nrm test
     ```

     

  

  

  



