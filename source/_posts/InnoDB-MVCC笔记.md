---
title: InnoDB MVCC笔记
date: 2021-01-25 18:05:12
tags: 
- MySQL
categories:
- Database
---



## 概述

多版本并发控制，MySQL中仅`innoDB`支持

依赖于：

1. 隐藏字段（`trx_id`，`roll_pointer`）
2. undo log
3. read view

<!-- more -->

## 读行为

### 快照读

读到undo log的某一个历史版本，不加锁的SELECT都属于快照读



### 当前读

读到最新版本，加锁的SELECT，对数据进行增删改都会进行当前读



## Read View

* 事务在使用MVCC机制进行快照读的时候产生的读视图，每个Read View都属于一个事务。事务启动时会生成数据库当前的一个快照，`InnoDB`为每个事务构造一个数组来记录并维护系统当前的活跃事务的id
* 仅`读已提交`和`可重复读`里使用read view

### 数据结构

* create_trx_id: 创建read view的事务id
* trx_ids: 当前系统活跃事务列表
* up_limit_id: 活跃事务中最小的事务id
* low_limit_id: 生成read view时刻系统分配的`下一个`事务id

### 记录的版本可见性规则

* 如果被访问的版本的trx_id和read view中的creator_trx_id一致，说明当前事务在访问自身修改过的记录，该版本`可`被当前事务访问
* 如果当前访问版本的trx_id`小于`up_limit_id，说明该版本是当前事务发生之`前`已经被提交过了的版本，当前版本`可`被当前事务访问
* 如果当前访问版本的trx_id`大于`low_limit_id，说明该版本是当前事务发生之`后`才开启的，当前版本`不可`被当前事务访问
* 如果当前访问版本的trx_id在up_limit_id和low_limit_id之间：
  1. 如果trx_id在当前read view的trx_ids列表中`存在`，说明该版本的事务依旧活跃，因此该版本`不可`被当前事务访问
  2. 如果trx_id在当前read view的trx_ids列表中`不存在`，说明该版本的事务已被提交，因此该版本`可`被当前事务访问

### read view的生成规则

* 读已提交级别下

  相同的查找条件下，事务每次执行SELECT都会生成一个read view

* 可重复读级别下

  相同的查找条件下，事务仅第一次执行SELECT的时候生成已给read view，后续相同的查询都使用该read view直到事务结束

### 解决幻读

> 可重复读级别下

假设条件：

* 表中存在一条id为1的记录，该记录隐藏列的事务id为10
* 一个事务A的id为20，执行`SELECT * from t where id > 0;`
* 同时一个事务B的id为30，执行`INSERT INTO t(id, name) value(2, "test");`
* 此时事务A的read view的状态为：
  1. create_trx_id: 20
  2. trx_ids: [20, 30]
  3. up_limit_id: 20
  4. low_limit_id: 31
* 事务B提交后，事务A查询的时候会看到id=2的记录，但是该记录的trx_id是30，在read view的trx_ids中存在，说明此时在read view创建时事务30还在活跃状态，因此该记录对当前事务不可见，因此会被过滤掉，从而解决幻读