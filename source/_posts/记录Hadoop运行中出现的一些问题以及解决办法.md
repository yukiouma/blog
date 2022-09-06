---
title: 记录Hadoop运行中出现的一些问题以及解决办法
date: 2019-11-04 23:28:48
tags: 
- HADOOP
categories:
- 大数据离线开发
---

1. MapReduce Job的驱动程序中出现：

```powershell
Exception in thread "main"java.lang.UnsatisfiedLinkError:org.apache.hadoop.io.nativeio.NativeIO$Windows.access0(Ljava/lang/String;I)Z
```

 <!-- more -->  

   Solution：

   > 其根本原因是因为在```C:\Windows\System32```中缺少```hadoop.dll```这个文件.....(晕.....)，因此我们只要把hadoop的bin下面的```hadoop.dll```复制至```C:\Windows\System32```中即可.....(╯‵□′)╯︵┻━┻

