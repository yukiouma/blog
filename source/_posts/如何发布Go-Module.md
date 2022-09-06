---
title: 如何发布Go Module
date: 2022-01-12 22:29:15
tags: 
- Golang
categories:
- Web开发
---



## 建立和发布Go模块的流程



### 引用本机其它位置的Go模块

假设我们有如下的目录

```bash
./module-learn/
├── module1
│   ├── go.mod
│   └── whattime.go
└── module2
    ├── go.mod
    └── main.go
```
<!-- more -->

module1和module2的模块名称分别为`example.com/module1`和`example.com/module2`

在`module1/whattime.go`中定义了一个方法

```go
package module1

import "time"

func WhatTimeIsItNow() string {
        return time.Now().Local().String()
}
```

我们希望在module2中引用它

在`module2/main.go`中如下定义

```go
package main

import (
	"fmt"

	"example.com/module1"
)

func main() {
	fmt.Printf("it's %s now.\n", module1.WhatTimeIsItNow())
}

```

为了能引用到module2的go mod范围以外的module1的方法，我们需要先在module2下先执行以下命令来替换外部module的路径

```bash
go mod edit -replace example.com/module1=../module1
```

完成后在module2下的`go.mod`文件会出现以下内容，

```go
replace example.com/module1 => ../module1
```

表示替换生效

此时我们只需要执行`go mod tidy`，查看`go.mod`发现成功引用了module1

```go
module example.com/module2

go 1.16

replace example.com/module1 => ../module1

require example.com/module1 v0.0.0-00010101000000-000000000000
```

运行module2，结果符合预期

```bash
[root@playground module2]# go run .
it's 2022-01-12 21:23:22.466931038 +0800 CST now.
```



### 发布一个Go模块

1. 首先创建一个go模块

```bash
go mod init github.com/AkiOuma/greeting
```

2. 在该模块中定义好一些方法后，创建一个仓库，提交到代码仓

3. 为该模块提交版本标签

```bash
git commit -m "commit v0.1.0"
git tag v0.1.0
git push origin v0.1.0
```

​		推送成功后，到仓库上查看提交的版本是否存在

4. 在其它项目中引用该模块

   使用`go get github.com/AkiOuma/greeting`或者`go mod tidy`能成功安装该模块，完成

```go
package main

import (
	"fmt"

	"github.com/AkiOuma/greeting"
	"github.com/AkiOuma/greeting/zh"
)

func main() {
	fmt.Println(greeting.Greet("yuki"))
	fmt.Println(zh.Greet("yuki"))
}
```



