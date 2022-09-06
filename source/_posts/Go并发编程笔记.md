---
title: Go并发编程笔记
date: 2022-02-11 22:24:47
tags: 
- Golang
categories:
- Web开发
---

# Goroutine


## 基本概念

* 轻量，可大量创建，以并发的特性去执行

* main函数就是作为goroutine执行的，是主goroutine，当该goroutine退出后，它派生的所有goroutine将被强制退出

* OS调度线程到可用的处理器上运行

* Go runtime调度goroutine在绑定到单个OS线程的逻辑处理器（一般简称为P）的队列上，最终各个线程到队列中获取一个goroutine去执行

<!-- more -->  

> 补充：并发与并行的概念
>
> * 并发：可以处理多个任务，无需等待上一个任务处理完在执行下一个任务，但不需要是同时处理
> * 并行：不同的任务在不同的CPU核心上同时进行处理



## 基本原则

* 让方法的调用者决定是否并发

  调用者来决定是否并发，意味着调用者可以随时销毁该goroutine，减少内存泄漏的问题

* 永远不要开启一个你不知道什么时候会结束的goroutine

  * 开启的goroutine什么时候会结束
  * 你有没有办法让他结束

* 数据的发送者才可以决定channel什么时候可以关闭

* 要注意channel关闭不能有二义性

  要区分channel关闭是由于数据被消费完成了，还是因为出现了错误导致的channel关闭

  



## 并发例子

* 内存泄露

  由于unbuffered channel里的数据没有人去获取而导致goroutine被阻塞

  ```go
  ch := make(chan result)
  
  ctx, cancel := context.WithTimeout(context.Background(), time.Duration(2))
  
  func search(term string) (string, error) {
      time.sleep(3)
      return "test", nil
  }
  
  go func() {
      record, err := search(term)
      ch <- result{record, err}
  }
  
  select {
      case <-ctx.Done():
      	return errors.New("timeout")
      case result := <-ch:
          // TODO
  }
  ```

  上面的代码，由于创建的channel是unbuffered channel，由于context超时比search函数的运行时间短，因此select会因为超时直接退出。当main goroutine还在运行时，上面的goroutine就会因为channel的值没有被获取和一直被阻塞无法被销毁，造成内存写漏

  

  改进办法：

  把channel改为带缓存的channel即可

  

* 埋点上报事件丢失

  埋点上报事件相对业务而言，一般属于旁路逻辑，为了避免阻塞主干业务逻辑，一般会开启一个goroutine单独去执行，如下面的例子所示：

  ```go
  func (a *App) Handle(w http.ResponseWriter, r *http.Request) {
      w.WriteHeader(http.StatusOK)
      go a.Track.Event("this event")
  }
  ```

  问题分析：

  上报事件的goroutine的生命周期没有被管理起来，因此，当应用的main goroutine因意外停止时，这些正在上报的goroutine可能会被强行直接退出，导致上报事件的丢失

  

  改进：

  1. 使用WaitGroup，保证上报事件全部结束之后在关闭

     ```go
     type Tracker struct {
         wg sync.WaitGroup
     }
     
     func (t *Tracker) Event(data string) {
         t.wg.Add(1)
         go func() {
             defer t.wg.Done()
             // 上报事件逻辑
         }()
     }
     
     func (t *Tracker) Shutdown() {
         t.wg.Wait()
     }
     
     func main() {
         var a App
         
         // 先等待应用服务全部终止
         
         // 保证等待所有的上报事件的goroutine全部结束后再退出main goroutine
         a.Track.Shutdown()
     }
     ```

     这个做法可以保证所有上报事件都结束之后再退出进程，但还存在以下问题

     * 会大量创建goroutine，其实不是比较理想的工作模型
     * 其次，如果上报时间特别长，有可能会导致对外的服务虽然停止了，但是main函数却永远都无法退出

     

  2. 使用channel，只是启动少量的goroutine去消费channel里面的数据，并使用context的超时功能，解决方案1中可能无法退出main函数的问题

     ```go
     type Tracker struct {
         ch chan string
         stop chan struct{}
     }
     
     func NewTracker() *Tracker {
         return &Tracker{
             ch: make(chan string, 10)
         }
     }
     
     func (t *Tracker) Event(ctx context.Context, data string) error {
         select {
             case t.ch <- data:
             	return nil
             case <-ctx.Done():
             	return ctx.Err()
         }
     }
     
     func (t *Tracker) Run() {
         for data := range t.ch {
             // 上报逻辑
     	}
         t.stop <- struct{}{}
     }
     
     func (t *Tracker) Shutdown(ctx context.Context) {
         close(t.ch)
         select {
             case <- t.stop:
             case <- ctx.Done():
         }
     }
     
     func main() {
         tr := NewTracker()
         ctx := context.Background()
         go tr.Run()
         // 对外服务的上报事件
         _ = tr.Event(ctx, "test1")
         _ = tr.Event(ctx, "test2")
         _ = tr.Event(ctx, "test3")
         
         ctx, cancel := context.WithDeadline(ctx, time.Now().Add(5*time.Second))
         defer cancel()
         tr.Shutdown(ctx)
     }
     ```

     上面的改进方法，使用了两个channel：

     * 一个buffered channel来负责接受上报数据，然后启用一个goroutine不断消费该channel里面堆积的上报数据

     * 一个unbuffered channel负责等待上报组件被停止与退出

       通过这两个channel，避免了每个上报事件都要单独创建goroutine这种大量创建goroutine的事件。同时主动管理了消费数据的goroutine，使得我们可以掌握该goroutine的生命周期

     * 使用一个超时context来保证当对外服务停止时，上报事件的服务可以在指定时间内退出

     流程分析：

     * 启动一个消费channel数据的goroutine(`go tr.Run()`)
     * 产生消费数据
     * 当应用停止时，创建一个超时context，使用该context来调用tracker的停止方法
     * 关闭tracker的方法中关闭channel通道，并向stop通道发送一个信号，此时，消费数据的方法已经被正常退出
     * 当收到stop通道的信号或者context超时，停止tracker的方法也可以被正常退出
     * main函数退出



## 应用生命周期

同时开启多个监听不同端口的应用时，我们应该做到，当一个应用因为意外退出时，其它应用应该同时被终止，以便开发者能及时知道应用出现问题

对于应用级别的服务管理，一般会抽象一个application lifecycle的管理，方便服务启动与停止，一般包括如下内容：

* 应用信息的注册
* 服务的启动/停止
* 信号注册
* 服务注册



# Memory Model

[Go内存模型官方指南](https://go.dev/ref/mem)

* 如何保证一个goroutine中看到另一个goroutine修改了变量的值？

  如果程序中修改数据时有其它的goroutine同时读取，那么必须将读取串行化，请使用channel或者其它的同步原语，如sync或者sync/atomic来保护数据

  

## Happen-Before

在一个goroutine中，读写一定是按照程序中的顺序来执行的。即编译器和处理器只有在不会改变这个goroutine的行为时才可以修改读写的执行顺序，这种现象称为重排（memory reordering）。

  由于重排，不同的goroutine可能会看到不同的执行顺序，例如：

  > goroutine 1: 执行了a = 1; b = 2

  由于a和b之间没有相互影响，因此对于该goroutine来说，先执行b = 2还是a = 1都是被允许的，因此，我们无法预测它们的执行顺序

  如果此时我们的goroutine b中有某些逻辑，是强依赖先更新a再更新b的这种逻辑的话，就有可能会出错，因为重排，它可能会看到b比a先更新

> 定义一个变量v，一个读操作r，一个写操作w
>
> 当下面条件满足时，对v的r是***被允许***看到对v的w：
>
> * r不先行发生于w
>
> * 在w后r前没有其它的对v的写操作
>
>   
>
> 当下列条件满足时，***保证***v的r看到其w：
>
> * w先行发生于r
>
> * 其它对v的写操作一定要在w前，或者r后
>
>   
>
> 对于变量v的零值初始化在内存模型中表现得与写操作相同
>
> 对大于single machine word的变量的读写操作表现得像以***不确定顺序对多个single machine word变量***的操作
>
> > 什么是Single Machine World？**中文翻译过来就是机器字。机器字的概念就是系统单次能处理的最小的数据容量。比如64位的操作系统，这就意味着我的机器字是8Byte,也就是说单次能处理的最大的数据容量是**8Byte，可以利用这点来进行原子赋值操作。

  

## Memory Reordering

在不改变用户语义的前提下，当高级语言被编译为汇编代码的时候，会进行各种各样的优化，有处理器重排和编译器重排等，比如

```go
var x int
for i := 0; i < 100; i++ {
    x = 1
    println(x)
}
```

上面这段代码，按用户编写的逻辑需要做100次x的相同的赋值操作

编译器有可能会将其优化成下面的样子

```go
x := 1
for i := 0; i < 100; i++ {
    println(x)
}
```

因为x每次赋值都是相同的，因此编译器会处于性能优化的考虑将x的相同赋值行为从循环结构中提取出来，因为不会影响原语义。



在多核心的场景下，我们是不能轻易判断两个程序是等价的

* 每个CPU核心都有自己的不同级别的cache来抚平内存与磁盘读写效率的差异

  如果没有锁机制的保护的话，一个核心更新一个变量的时候，可能结果只是停留在某一个级别的缓存当中，当另一个核心需要使用到同一个变量的时候，可能会因赋值结果还在核心缓存中没有及时刷盘落入内存中，导致读不到最新的值，从而引发不可预期的结果





# Package Sync



## Data Race

data race是两个及以上的goroutine访问同一个资源（变量或者数据结构），并尝试对该资源进行读写儿不考虑其它的goroutine

> go自带的data race检测方案：race detector
>
> go build -race
>
> go test -race
>
> 注意，使用race detecto时，当出现了data race会让进程停止，不建议生产环境使用



我们要尽量避免对go原生的一些数据结构（map, slice, interface）去做假设

* interface的底层由两个machine word的值组成：type和data

  当我们在data race的情况下给interface赋值，有可能会导致一种情况，type被更改了，但是里面指向的data还没有进行更改这种以外状况，甚至有可能引发panic



## sync.atomic

在读多写少的场景，特别是读特别多的场景，atomic.Value的性能甚至比读写锁的性能更好

不过主要还是需要进行benchmark进行测试来决定使用读写锁还是atomic.Value

```bash
go test -bench=.
```

atomic.Value的实现原理使用的是COW(copy-on-write)



### COW

copy-on-write，写时拷贝，是计算机程序设计领域的一种优化策略，其核心思想是，当有多个调用者都需要请求相同资源时，一开始资源只会有一份，多个调用者共同读取这一份资源，当某个调用者需要修改数据的时候，才会分配一块内存，将数据拷贝过去，供这个调用者使用，而其他调用者依然还是读取最原始的那份数据。每次有调用者需要修改数据时，就会重复一次拷贝流程，供调用者修改使用。

[Copy-On-Write原理简述](https://cllc.fun/2020/03/16/linux-copy-on-write/)

> 在fork()调用之后，只会给子进程分配虚拟内存地址，而父子进程的虚拟内存地址虽然不同，但是映射到物理内存上都是同一块区域，子进程的代码段、数据段、堆栈都是指向父进程的物理空间。
>
> 并且此时父进程中所有对应的内存页都会被标记为只读，父子进程都可以正常读取内存数据，当其中某个进程需要更新数据时，检测到内存页是read-only的，内存管理单元（MMU）便会抛出一个页面异常中断，（page-fault），在处理异常时，内核便会把触发异常的内存页拷贝一份（其他内存页还是共享的一份），让父子进程各自持有一份。
>
> 这样做的好处不言而喻，能极大的提高fork操作时的效率，但是坏处是，如果fork之后，两个进程各自频繁的更新数据，则会导致大量的分页错误，这样就得不偿失了。

Copy-On-Write是redis的BGSAVE指令实现的基本原理

Copy-On-Write在服务降级以及本地缓存的场景也会经常用到



## Mutex

在Go1.8版本之前

> 假设有两个goroutine，分别成为g1和g2
>
> g1采取先上锁，然会休眠100毫秒，再释放锁的模式
>
> g2采取先休眠100毫秒，再上锁，然后马上释放锁的模式
>
> 
>
> 测是两个锁进行竞争的时候，g1获取到锁的概率，远远大于g2

造成上面这个案例的结果的原因是：

> g1在获取到并持有锁时，g2会被放入等待队列中，等待g1释放锁后，go的scheduler将g2标记为可运行，然后再重新去竞争锁。但是，go的scheduler去标记（唤醒）g2的时候，很可能锁又再次被g1持有了，然后g2不得不再次回到等待队列等待scheduler再次唤醒，因此造成g2比g1难获得锁的情况



### 实现模型

* Barging

  这种模式吞吐会比较高，当锁被释放时，会唤醒第一个等待者，直接把锁给第一个等待者或者给第一个请求锁的人

* Handsoff

  当锁释放的时候，锁会一直持有知道第一个等待者准备好获取锁。这种模式吞吐会下降，但是goroutine拿到锁的概率相对公平

* Spinning

  自旋，再等待队列为空或者应用程重度使用锁的时候，效果较好

* Go1.8以后采用的是Barging和Spining的结合实现
  * 当同时满足下列条件时，goroutine将自旋几次，自旋后，goroutine park
    * 本地队列为空
    * P的数量要大于1
  * 在Go1.9后，添加了一个饥饿模式来解决获取锁的公平问题。所有等待锁时间超过一毫秒的goroutine会被标记为饥饿，当被标记为饥饿状态时，unlock方法会使用handsoff模式将锁直接交给第一个等待者。在饥饿模式下，自旋会被停用，因为传入的goroutines将没有机会获取为下一个等待者保留的锁



## errgroup

[errgroup](https://pkg.go.dev/golang.org/x/sync/errgroup)的核心原里是利用sync.Waitgroup管理并执行goroutine，非常适合以下场景

* 并行工作流
* 错误处理与优雅降级
* context传播与取消
* 利用局部变量+闭包



### sync.Pool

sync.Pool的场景是用来保存和复用临时对象，以减少内存分配，降低GC压力，适合Request-Driven场景（指请求一个数据的时候，如果pool中没有数据，可以在获取或者计算完数据结果后放入pool中，下一次调用时，如果pool中的数据符合需求，可直接提出来使用，避免再次获取或者运算，提高性能）

因为sync.Pool中防止的对象，会说不准什么时候被回收掉（1.13后引入victim cache，但是最多只会保留两轮GC）

我们使用Pool的时候注意不应该放带状态的，可以被随时回收不造成不良影响的对象



# Package Channel



## 概念

channel是一种类型安全的消息队列，充当goroutine之间的管道，将通过它同步的进行任意资源的交换。

channel分为：

* unbuffered channel

  1. 无缓冲通道，发送者需要等接收者接受值才会解除阻塞，意味着发送者解除阻塞了，接收者就一定接收到了数据，但是可能会产生时间延迟的代价

  2. receiver先于sender发生

  3. 适合同步通信的场景

* buffered channel

  1. 发送者只有在通道被填满之后才会产生阻塞，但是不保证数据一定到达接收者。buffer越大，越难以保证数据到达

  2. sender先于receiver发生

  3. 适合异步通信场景

创建channel时定义缓冲区的大小会极大地影响程序性能

我们要注意，一定要保证没有人往channel发送消息了才能close



## 常用的并发Pattern

* Timing out
* Moving on
* Pipeline
* Fan-out, Fan-in
* Cancellation
* Context

reference:

[Go Concurrency Patterns: Timing out, moving on](https://go.dev/blog/concurrency-timeouts)

[Go Concurrency Patterns: Pipelines and cancellation](https://go.dev/blog/pipelines)



## Context

可以使得跨API边界的请求范围元数据，取消信号和截至时间很容易传递到处理请求设计的所有goroutine中（显式传递）

当一个请求被取消或者超时时，处理该请求的goroutine都可以被快速退出（fail fast）来迅速释放资源



### 集成context到API

将context集成到api时，要注意他的作用域应该是请求级别的

* 首个参数为context

* 一个请求结构体中的一个可选的配置

  这里要注意的是，我们一定要明确某个结构体是与请求相关的时候，才将context作为其字段放入，如http的Request结构体。但如果一个结构体与请求无关时，我们要尽可能避免挂载context对象

目前比较好的实践是，context应该在整个应用程序中流动，贯穿所有代码



### WithValue

每次调用context.WithValue都会新创建一个context。当尝试从一个context中获取一个value时，会先判定该key在当前context的key是否相等，否在会递归调用父节点的context知道key匹配

value context的定义如下

```go
type valueCtx struct {
    Context
    key, val interface{}
}
```

需要注意的是：valueCtx的key，我们应该使用一个自定义的类型去替代Go中的基本类型，如：

```go
// 假设我们想使用string作为key的时候
type KeyString string
ctx := context.WithValue(context.Background(), KeyString("myKey"), "myValue")
```



可以看到，每次产生的context是通过链表的形式管理起来的，因此，我们应该尽量避免在context中多次挂载value（链表查询的时间复杂度为O(n)），当要挂载较多的值时，尽可能一次性整合到一个数据结构中再挂载上去。

挂载上去的应该是请求级别的一些元数据

如果要修改context里面的value，一定要采取copy on write的思路，先深拷贝一份数据出来，再新生成一个context，再把新的value放入新的context，再传入下一个调用，下面是一个较好的实践

```go
type KeyString string

func changeCtx(ctx context.Context) {
	// 假设原来的context是一个valueCtx，里面有一个kv是a=100
    // 现在我们想把a中的值加上100，然后再传递给下一个函数doSomething
    key := KeyString("a")
    orginA := ctx.Value(key)
    if orginA != nil {
        if value, ok := orginA.(int);ok {
        	ctx = context.WithValue(ctx, key, value + 100)
            doSomething(ctx)
		}
    }
}
```

这样子做的目的是，不会污染了同时调用了同一个context的其它函数，避免data race。context本质上只是用来传递信息的，它不应该被使用来作为控制流



在替换context的时候，一定要用下面方法中的一种：

* WithCancel
* WithDeadline
* WithTimeout
* WithValue



### context cancel

当一个context被取消时，所有从他派生的context（链表上的context被递归取消）也会被取消，从而让整个调用链中所有监听cancel的goroutine推出

所有被阻塞，或者长时间的操作，应该考虑可以被调用者随时cancel，实现超时控制，一个好的实践如下：

```go
func main() {
    ctx, cancel := context.WithDeadLine(context.Background(), time.Now().Add(time.Second))
    // 既是有超时控制，我们也应该记得在函数退出的时候调用这个cancel方法
    defer cancel()
    
    select {
        case <-time.After(2 * time.Second):
        case <- ctx.Done():
    }
}
```









