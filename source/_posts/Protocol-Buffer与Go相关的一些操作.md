---
title: Protocol Buffer与Go相关的一些操作
date: 2023-01-31 15:14:07
tags: 
- Protocol Buffer
- Go
categories:
- Web开发
---

总结一下使用protocol buffer和go相关的一些操作

# protoc

## --go_out

`protoc`命令首先需要使用添加标记`--go_out`，有两层含义：

* 输出的是go文件
* 输出的go文件存放的位置

没有该标志的时候会无法运行



## --proto_path

如果需要导入自定义，而且不在一个目录下的proto文件时，我们需要指定--proto_path标志，以告诉`protoc`可以到哪里去查找导入的proto文件

`protoc`默认会去查找的路径是：

* `protoc`的启动路径
* `protoc`的安装路径的`include`目录下的proto文件



## --go_opt

`protoc`为`protoc-gen-go`传参数的标志，可以重复传入多个该标志，格式如下：

```bash
--go_opt=<flag name>=<flag value>
```

`go_opt`有以下可选参数：

* paths

  paths可以选择以下内容：

  * import

    当paths标志的值是import时，生成的`pb.go`文件的路径将在`--go_out`路径的基础上，拼接上`.proto`文件中的`option go_package`中定义的值，作为最终的生成路径，这是默认的输出模式，如果没有指定paths标志，则paths默认选择import输出模式

    例如有以下路径，内容有：

    ```bash
    └── pb
        ├── demo
            └── v1
                └── demo.proto
    ```

    其中`demo.proto`中的`go_package`参数是`github.com/yuki/api/go/demo/v1`

    我们在根路径下执行：

    ```bash
    protoc --go_out=. --go_opt=paths=import ./pb/demo/v1/demo.proto
    ```

    那么生成`pb.go`文件的后的内容将会是

    ```bash
    .
    ├── github.com
    │   └── yuki
    │       └── api
    │           └── go
    │               └── demo
    │                   └── v1
    │                       └── demo.pb.go
    └── pb
        ├── demo
            └── v1
                └── demo.proto
    ```

    可以看到，在根目录下按照`go_package`生成了对应的路径结构

    

  * source_relative

    当paths标志的值是source_relative时，则会无视`go_package`指定的路径，生成的`pb.go`文件将与其对应的`.proto`在同一个路径下

* module

  module参数是用来指定一个路径前缀的，在`--go_opt=paths=import`的输出模式下，可以修剪`go_package`中定义的前缀的部分路径，以满足我们实际开发的时候的路径

  参考上面的例子，我们有下面的目录：

  ```bash
  └── pb
      ├── demo
          └── v1
              └── demo.proto
  ```

  其中`demo.proto`中的`go_package`参数是`github.com/yuki/api/go/demo/v1`

  我们在根路径下执行：

  ```bash
  protoc --go_out=. --go_opt=paths=import --go_opt=module=github.com/yuki/api ./pb/demo/v1/demo.proto
  ```

  由于我们指定了`--go_opt=module=github.com/yuki/api`，编译器会修剪原来`go_package`前缀满足的这部分内容，也就是实际输出的`go_package`的路径会是`go/demo/v1`，我们可以得到下面的目录结构

  ```bash
  .
  ├── go
  │   ├── demo
  │   │   └── v1
  │   │       └── demo.pb.go
  └── pb
      ├── demo
          └── v1
              └── demo.proto
  ```

  

# proto文件



## import

导入其它的`.proto`文件定义的消息格式

### 直接导入

```protobuf
import "<location>/<filename>.proto"
```

直接将其它路径下的`.proto`定义导入本文件。使用其它文件的定义时需要带上其它文件声明的package名称

注意，import中声明的是一个相对路径，编译器会尝试将其与下面的路径进行组合来进行查找具体的`.proto`文件

* `protoc`命令中`--proto_path`标志声明的路径
* 启动`protoc`命令的路径
* `protoc`的安装路径下的`include`目录

如果上面的组合出来的路径均表明没有该文件，编译器将报错

假设我们有以下路径：

```bash
.
└── pb
    └── greet
        └── v1
            ├── greet.proto
            └── user.proto
```

`user.proto`文件内容如下

```protobuf
syntax = "proto3";

package user;

option go_package = "github.com/yuki/api/go/user/v1";

import "google/protobuf/timestamp.proto";

enum Gender {
  MISS = 0;
  MR = 1;
}

message User {
  string firstName = 1;
  string lastName = 2;
  Gender gender = 3;
  double age = 4;
  google.protobuf.Timestamp birthday = 5;
}
```

这里由于`google/protobuf/timestamp.proto`路径存在于`protoc`的安装路径下的`include`目录，因此编译器能成功找到

`greet.proto`文件内容如下

```protobuf
syntax = "proto3";

package greet;

option go_package = "github.com/yuki/api/go/greet/v1";

import "pb/greet/v1/user.proto";

message Greet {
  greet.User user = 1;
}
```

由于项目根路径下存在路径`pb/greet/v1/user.proto`，因此编译器可以找到该文件定义，并且由于`user.proto`中定义的package名称是greet，因此在本文件中调用它定义的消息题的时候需要带上package名称



### 间接导入

假设一种情况，我们现在需要将原本和`greet.proto`同一个文件夹下面的`user.proto`文件移动到别的地方了，我们有两种选择：

* 直接修改`greet.proto`文件中的import路径
* 不修改`greet.proto`文件，将原本同路径下的`user.proto`修改为占位文件

我们来讨论第二种选择的目录结构如下：

```bash
.
└── pb
    ├── greet
    │   └── v1
    │       ├── greet.proto
    │       └── user.proto
    └── user
        └── v1
            └── user.proto
```

可以看到我们在pb下新建了一个user的文件夹存放先前的`user.proto`（文件内容完全一致），但是原来的`user.proto`我们也没有进行移除，而是将其改为如下

```protobuf
syntax = "proto3";

package greet;

option go_package = "github.com/yuki/api/go/greet/v1";

import public "pb/user/v1/user.proto";

```

在import关键字和路径中间使用一个public关键字，可以将新的`user.proto`路径写入路径中，表示在本文件中导入该定义，再将该定义转发给其它导入本文件的文件，此时`greet.proto`是完全不用修改的

（这里注意一点，`greet.proto`完全不用修改的前提是，新的`user.proto`的package名称没有发生变化。如果发生了变化，则`greet.proto`也要做同步的修改）



## option

与go相关的是`go_package`参数，用来指定生成的go文件的路径