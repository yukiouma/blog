---
title: exceljs的使用记录
date: 2019-11-23 17:08:48
tags: 
- Node.js
categories:
- Web开发
---



最近在写公司的员工管理系统的后台，有个蛋疼需求是员工在填写工作记录的时候不肯乖乖到系统里面填非要先写到excel的```xlsx```里然后把```xlsx```传上去（MDZZ.....），在处理excel部分的内容的时候使用了一个强大的excel处理插件[exceljs]( https://github.com/exceljs/exceljs )，记录一下自己在使用这个插件的过程中遇到的一些问题以及解决方法。


<!-- more -->
## 无法通过流的形式读取到```xlsx```文件

这个问题.....其实还在Readme的Backlog里面.....也就是还带完善，除非自己去把它完善了\_(:з)∠)\_，否则目前还是用不了的.....

所以我们只能采用绕圈子的方式了，第一种方法是直接上传的时候把```xlsx```传到服务器中，然后用```workbook.xlsx.readFile(filename)```这个方法去读取文件对象，但是这种操作方法本人觉得要占服务器的存储，一点也不优雅.....

第二种方法是我们依然是以流的方式获得```xlsx```的内容，然后把流直接转换为buffer，然后通过```workbook.xlsx.load(buffer)```来获取内容（亲测有效~），具体实现如下：

1. 我们先创建一个stream转buffer的方法

   ```javascript
   //app/extend/helper.js
   
   'use strict';
   
   module.exports = {
       streamToBuffer(stream) {  
           return new Promise((resolve, reject) => {
             let buffers = [];
             stream.on('error', reject);
             stream.on('data', (data) => buffers.push(data));
             stream.on('end', () => resolve(Buffer.concat(buffers)));
           });
         }
     };
   ```

2. 创建一个controller来读取buffer里的内容

   ```javascript
   //app/controller/upload.js
   
   'use strict';
   
   const Controller = require('egg').Controller;
   const Excel = require('exceljs');
   
   class UploadController extends Controller {
     async create() {
       const { ctx } = this;
       // 获取前端传回来的（单个）文件流
       const stream = await ctx.getFileStream();
       // 将stream转换为buffer
       const buffer = await ctx.helper.streamToBuffer(stream);
       // 读取buffer的内容，并返回给前端  
       const workbook = new Excel.Workbook();
       await workbook.xlsx.load(buffer);
       const worksheet = workbook.getWorksheet('Sheet1');
       ctx.body = worksheet.getColumn(1).values;
     }
   }
   
   module.exports = UploadController;
   
   ```

这样我们就能获得前端传回来的```xlsx```的内容然后进行进一步验证和写入数据库的操作啦~（还是想吐槽一些同事玛德excel真的就这么好用吗QAQ）