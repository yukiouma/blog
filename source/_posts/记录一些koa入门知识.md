---
title: 记录一些koa入门知识
date: 2019-11-09 21:08:26
tags: 
- Node.js
categories:
- Web开发
---

### Koa 安装

```shell
// 初始化一个node项目
npm init -yes
// 安装koa
npm i koa --save
```

---


<!-- more -->
### 启动一个koa项目

```javascript
const koa = require('koa');

const app = new koa();

app.use(async(ctx) => {
    ctx.body = "Hello koa!";
})

app.listen(4200);
```

Then visit localhost:4200 you can see "Hello koa!"

---



### koa路由

* 安装

```shell
npm i koa-router
```

* 配置一个路由实例

```javascript
const Koa = require('koa');
const Router = require('koa-router');

const app = new Koa();
const router = new Router();

//配置静态路由
router.get('/', async(ctx) => {
    ctx.body = 'HomePage';
}).get('/news', async(ctx) => {
    ctx.body = 'News';
})

//配置一个动态路由
router.get('/page/:number', async(ctx) => {
    ctx.body = `This is paeg ${ctx.params.number}`;
})

//启动路由
app
    .use(router.routes())
    .use(router.allowedMethods())

app.listen(4200);
```

---



### Middleware

* middleware主要的思想是拦截请求，然后执行一些操作之后，（再根据操作的结果决定）进入下一步的路由中。在请求进入相应的路由指定的组件中获得数据即将返回给客户端的浏览器时，再次拦截下来对所请求到的数据进一步加工，即所谓的洋葱圈模型（以一条直线通过一个洋葱时，在进入到洋葱的中心位置之后，再出来到洋葱外面时必定要先经过之前曾经穿过的洋葱层）
* middleware的函数时next，需要注意的是，作为回调函数时不能单独使用next，需要和ctx一起使用
* 基本用法有两种
  1. 在app.use中使用拦截指定或者所有请求
  2. 在router.get中拦截指定请求

```javascript
const Koa = require('koa');
const Router = require('koa-router');

const app = new Koa();
const router = new Router();

// 设置middleware
app.use(async(ctx, next) => {
    //在控制台打印当前请求的地址，这个是在进入路由匹配之前的行为
    console.log(`You're visiting ${ctx.url}`)
    await next();
    
    //若请求没有找到匹配的路由，此时状态码会变为404，这个是匹配路由之后的行为
    if (ctx.status == 404) {
        ctx.status = 404;
        ctx.body = 'Sorry page not found...';
    }
})

// 在router中使用middleware
router.get('/', async(ctx) => {
    ctx.body = 'HomePage';
}).get('/news', async(ctx, next) => {		//本次对"/news"拦截只打印控制台
    console.log("This is a middleware");
    next();
}).get('/news', async(ctx) => {				//本次对"/news"拦截返回body
    ctx.body = 'News';
});
// 启动路由
app.use(router.routes())
    .use(router.allowedMethods());

app.listen(4200);
```

---



### Cookies

在koa中获取cookies对象：```ctx.cookies```（该对象不可被遍历....）

* 基本使用

```javascript
const Koa = require('koa');
const Router = require('koa-router');

const app = new Koa();
const router = new Router();

router.get('/', async(ctx) => {
    // 在/页面设置一个cookies键值对
    ctx.cookies.set('name', 'koa', {
        // 该cookie多久后失效
        maxAge: 1000 * 60 * 60,
        //
    });
    ctx.body = 'Hi koa';
});

router.get('/page', async(ctx) => {
    // 在page页面打印cookies的指定键值对
    ctx.body = 'Hello, ' + ctx.cookies.get('name');
})

app.use(router.routes())
    .use(router.allowedMethods());

app.listen(4200);
```

* ctx.cookies.set中的一些选项

  | option name | value   | explaination                           |
  | ----------- | ------- | -------------------------------------- |
  | maxAge      | int     | 从现在起该cookie多久后过期，单位是毫秒 |
  | path        | string  | 指定该cookie有效的路径                 |
  | domain      | string  | cookie域名                             |
  | secure      | boolean | 是否只允许https访问                    |
  | httpOnly    | boolean | 是否只有服务端才可以访问cookie         |
  | expires     | Date    | cookie到某个具体日期失效               |

  

### Session

* installation

  ```shell
  npm i koa-session --save
  ```

* 与cookies不同，session在使用前需要配置middleware

配置实例：

```javascript
const Koa = require('koa');
const Router = require('koa-router');
const Session = require('koa-session');

const app = new Koa();
const router = new Router();

//设置cookied的签名，用于加密，可以自由设置数组值
app.keys = ['yuki'] 

// 配置middleware
const config = {
    key: 'koa:sess', // 默认，无需修改？？
    maxAge: 60 * 60 * 1000, // 过期时间
    overwrite: true, // 无需设置
    httpOnly: true,
    signed: true, // 是否对cookies进行签名，一般用true
    rolling: false, // 是否每次请求的时候都强行设置cookies，刷新cookies的初始化时间
    renew: true, // 是否蛾子即将过期是刷新cookies
}
app.use(Session(config, app));
// 配置middleware完成


router.get('/login', async(ctx) => {
    // 在/login页面设置一个session键值对
    ctx.session.user = 'yuki';
    ctx.body = 'Login';
});

router.get('/', async(ctx) => {
    //获取并打印session内容
    ctx.body = `Hi, ${ctx.session.user}`;
})

app.use(router.routes())
    .use(router.allowedMethods());

app.listen(4200);
```

