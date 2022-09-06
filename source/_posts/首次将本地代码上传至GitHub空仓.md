---
title: 首次将本地代码上传至GitHub空仓
date: 2020-12-16 21:22:06
tags: 
- git
categories:
- 其它
---

## 前提

* 已安装好git
* Github账号
* 已配置好SSH
<!-- more -->
## 步骤

1. 在目标文件夹根目录初始化git仓库

   ```bash
   git init
   ```

   

2. 配置```.gitignore```

   在根目录中添加```.gitignore```，将不需要上传的文件或文件夹路径写入

   ```gitignore
   dist
   node_modules
   ```

   

3. 将所有需要上传的文件提交

   ```bash
   git add -A
   ```

   

4. 加上本次提交所填写的备注

   ```bash
   git commit -m "first commit"
   ```

   

5. 切换至main分支

   Github的默认分支为main分支，所以我们要切换为main分支上传

   ```bash
   git branch -M main
   ```

   

6. 添加远程仓库

   ```bash
   git remote add origin git@github.com:<your github account>/<your repository name>.git
   ```

   

7. 推送至远程仓库

   ```bash
   git push -u origin main
   ```

   

8. 到GitHub仓库中查看是否推送成功

