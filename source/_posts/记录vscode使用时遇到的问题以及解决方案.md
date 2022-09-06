---
title: 记录vscode使用时遇到的问题以及解决方案
date: 2019-11-17 15:05:26
tags: 
- VS Code
categories:
- 其它
---



## 运行debug时无法断点调试

* 问题描述：运行debug时无法断点调试，并且断点列表出显示：```Breakpoint set but not yet bound```
 <!-- more -->
* 解决过程：

  1. 首先打开了数个项目，开启debug后发现均无法实现断点调试，结合昨天刚对win10进行更新......初步判断是系统更新导致原本的debug配置无效了。

     (原本debug的配置为egg官方推荐使用的配置，如下)

     ```json
     // .vscode/launch.json
     {
       "version": "0.2.0",
       "configurations": [
         {
           "name": "Launch Egg",
           "type": "node",
           "request": "launch",
           "cwd": "${workspaceRoot}",
           "runtimeExecutable": "npm",
           "windows": { "runtimeExecutable": "npm.cmd" },
           "runtimeArgs": [ "run", "debug" ],
           "console": "integratedTerminal",
           "protocol": "auto",
           "restart": true,
           "port": 9229,
           "autoAttachChildProcesses": true
         }
       ]
     }
     ```

  2. 在看到这篇帖子后(vscode打断点无效)[ https://github.com/eggjs/egg/issues/1048 ]，更改了debug的配置

     ```json
     // .vscode/launch.json
     {
         "version": "0.2.0",
         "configurations": [
             {
                 "type": "node",
                 "request": "launch",
                 "name": "Egg Debug",
                 "runtimeExecutable": "npm",
                 "runtimeArgs": [
                     "run",
                     "debug",
                     "--",
                     "--inspect-brk"
                 ],
                 "console": "integratedTerminal",
                 "restart": true,
                 "protocol": "auto",
                 "port": 9229,
                 "autoAttachChildProcesses": true
             },
             {
                 "type": "node",
                 "request": "launch",
                 "name": "Egg Test",
                 "runtimeExecutable": "npm",
                 "runtimeArgs": [
                     "run",
                     "test-local",
                     "--",
                     "--inspect-brk"
                 ],
                 "protocol": "auto",
                 "port": 9229,
                 "autoAttachChildProcesses": true
             },
             {
                 "type": "node",
                 "request": "attach",
                 "name": "Egg Attach to remote",
                 "localRoot": "${workspaceRoot}",
                 "remoteRoot": "/usr/src/app",
                 "address": "localhost",
                 "protocol": "auto",
                 "port": 9999
             }
         ]
     }
     ```

     

  3. 再次启动debug发现可以进行断点调试了，不过每次启动的时候都会莫名其妙地在egg源码中跳出两个断点（不是自己断的...），然后在package.json中更改下面一处即可

     ```json
     // package.json  
     "egg": {
         "declarations": false
       },
     ```




