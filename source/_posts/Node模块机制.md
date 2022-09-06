---
title: Node模块机制
date: 2020-07-25 15:20:19
tags: 
- Nodejs
categories:
- Web开发
---



## 模块机制

Node的模块是在[CommonJs](http://www.commonjs.org/)的基础上对模块的规范进行了一定的取舍，再结合自身特性的需求去实现的。

<!-- more -->

### 模块标识符分类

1. 核心模块
2. 相对路径的文件模块
3. 绝对路径的文件模块
4. 非路径形式的文件模块（自定义模块）



### 自定义模块

#### 模块路径

模块路径是Node在定位文件模块的具体文件时制定的一个查找策略，我们可以通过以下方法查看对于一个文件而言的一个具体的模块路径：

```javascript
console.log(module.paths);
```

结果为：

```shell
[
  '/root/Project/node_practice/demo01/node_modules',
  '/root/Project/node_practice/node_modules',
  '/root/Project/node_modules',
  '/root/node_modules',
  '/node_modules'
]
```

上面的数组表示自定义模块的查找顺序，若在某一层找到了需要的模块便进行编译与加载，停止查找。但是这种递归扫描式的查找方式是最为费时的。



#### 非路径的文件模块的查找顺序

> 下面的流程假定我们想导入的模块名称叫md

![image-20200803230816443](image-20200803230816443.png)

#### exports和module.exports的区别

在Node中，每个文件模块都是一个对象，每个文件本身都带有一个Module对象，Module对象的内容如下：

```javascript
// myModule.js
console.log(module);
```

```shell
[root@Node demo01]# node myModule.js 
Module {
  id: '.',
  path: '/root/Project/node_practice/demo01',
  exports: {},
  parent: null,
  filename: '/root/Project/node_practice/demo01/myModule.js',
  loaded: false,
  children: [],
  paths: [
    '/root/Project/node_practice/demo01/node_modules',
    '/root/Project/node_practice/node_modules',
    '/root/Project/node_modules',
    '/root/node_modules',
    '/node_modules'
  ]
}
```



当我们使用exports.xx时：

```javascript
// myModule.js
exports.a = 123;

exports.b = function() {
    console.log(123);
}

console.log(module);
```

```shell
[root@Node demo01]# node myModule.js 
Module {
  id: '.',
  path: '/root/Project/node_practice/demo01',
  exports: { a: 123, b: [Function] },
  parent: null,
  filename: '/root/Project/node_practice/demo01/myModule.js',
  loaded: false,
  children: [],
  paths: [
    '/root/Project/node_practice/demo01/node_modules',
    '/root/Project/node_practice/node_modules',
    '/root/Project/node_modules',
    '/root/node_modules',
    '/node_modules'
  ]
}
```

从控制台结果可以看到，我们使用exports.xx时，会在Module对象的exports对象中添加相应的对象，而其它文件调用该模块时则是获得exports这个对象

```javascript
// myModule2.js
const myModule = require('./myModule');

console.log(myModule);	// { a: 123, b: [Function] }
console.log(myModule.a);	// 123
myModule.b();				// 123
```



当我们使用module.exports时：

```javascript
// myModule.js
module.exports = class {
    constructor(a) {
        this.a = a;
    }

    b() {
        console.log(123);
    }
}

exports.c = { a: 123, b: [Function] };

exports.d = function() {
    console.log(123);
};

console.log(module);
```

```shell
Module {
  id: '.',
  path: '/root/Project/node_practice/demo01',
  exports: [Function],
  parent: null,
  filename: '/root/Project/node_practice/demo01/myModule.js',
  loaded: false,
  children: [],
  paths: [
    '/root/Project/node_practice/demo01/node_modules',
    '/root/Project/node_practice/node_modules',
    '/root/Project/node_modules',
    '/root/node_modules',
    '/node_modules'
  ]
}
```

从控制台结果我们可以看到，使用module.exports时是将exports对象完全覆盖，并且之后使用exports.xx是不会被写入exports对象的，使用module.exports可以直接使得模块输出一个构造函数（类）

