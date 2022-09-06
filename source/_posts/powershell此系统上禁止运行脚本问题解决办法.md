---
title: windows powershell此系统上禁止运行脚本问题解决办法
date: 2019-10-30 23:05:16
tags: 
- powershell
categories:
- 其它
---

问题描述：

* 在powershell（或者调用powershell的IDE中）使用DOS命令时提示：

```powershell
无法加载文件ps1，因为在此系统中禁止执行脚本。有关详细信息，请参阅 "get-help about_signing
```


<!-- more -->
解决步骤：

1. 使用管理员权限打开powershell

2. 查看当前脚本执行策略

   ```powershell
   get-executionpolicy
   ```

   若返回``` Restricted ```，说明不允许执行任何脚本 

3. 继续执行以下命令，并且在系统提示后输入Y即可

   ```powershell
   Set-ExecutionPolicy RemoteSigned
   ```

   

