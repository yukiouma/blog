---
title: Go错误处理笔记
date: 2022-02-12 10:48:58
tags: 
- Golang
categories:
- Web开发
---


# Error



## 概述

error在go中是一个接口，定义如下

```go
type error interface {
    Error() string
} 
```

<!-- more --> 

标准库里的errors包的实现：

```go
type errorString struct {
    s string
}

func (e *errorString) Error() string {
    return e.s
}

func New(text string) error {
    return &errorString{text}
}
```



## 对比panic

error是函数或者方法主动抛出，希望调用者手动去处理的错误

panic意味着发生严重错误，程序不应该继续运行下去，并且不能假设调用者来解决panic



## 定义Error

最佳实践为：`package name: error information`

例如：

```go
// from bufio
var ErrBufferFull = errors.New("bufio: buffer full")
```



# Error Type



## Sentinel Error

预定义的特定错误

* sentinel值是最不灵活的错误处理策略，我们不应该依赖检查error.Error的输出
* sentinel error会成为你的API的公共部分，会增大API的暴露的表面积（如果接口的表面积越大，则抽象越脆弱），并且会在两个包之间创建依赖，这样就增大了import loop的风险

* 我们应该尽可能避免直接使用sentinel errors



## Error Types

使用switch + type断言来判断错误类型，能获取更多的上下文信息

但是还是没有解决包之间的强耦合的问题

尽可能避免直接使用error types



## Opaque Error

不透明的错误处理，调用者虽然知道发生了错误，但是无法知道错误的内部，仅仅能知道该次调用成功或者失败了

其实就是`if err != nil {}`这种处理方式

但是在一些情况下，这种二分错误处理是不够的，有时候调用方需要知道具体的错误类型，根据错误类型去进行下一步的操作（例如因为网络原因的错误决定是否要进行重试）

这种情况下，我们可以断言错误实现了特定的行为，而不是断言错误是特定的类型或者值，比如下面这个例子：

```go
type myerror struct {}
func (*myerror) Error() string {
    return "my error"
}

func IsMyError(err error) bool {
    _, ok := err.(myerror)
    return ok
}
```

通过暴露一个类型断言的方法，来避免直接暴露错误的类型，是比较推荐的实践



# Handling Error



## 处理位置

错误处理应尽可能在缩进行中进行

无错误的正常流程代码，应成为一条直线，而不是缩进的代码。我们处理错误的时候，应尽可能在`if err != nil {}`的缩进位置去处理错误的情形，避免代码主干逻辑混乱



## 减少错误处理

处理调用结构体内部的方法产生的错误，我们可以在结构体内部包裹一个不对外暴露的错误来讲错误暂存，在结构体的方法前面加上错误判断，如果暂存的错误不为nil，则不做任何处理，直接讲错误返回。这种模式下，调用方则可以减少大量的错误处理。参考下面的例子：

```go
type errWriter struct {
    io.Writer
    err error
}

func (e *errWriter) Write(buf []byte) (int, error) {
    if e.err != nil {
        return 0, e.err
    }
    var n int
    n, e.err = e.Writer.Write(buf)
    return n, nil
}
```

原本`io.Writer.Write`方法每次都会返回一个错误需要调用者来进行处理，上面的例子使用一个结构体将其与一个暂存错误包裹起来，这样调用方仅需要处理最后的那个错误，而不是每写入一次就要处理一次错误，减少了代码量



## Wrap Error

错误的调用堆栈信息对调用者而言十分重要，否则在出现错误的时候调用者就要一层层往下查找调用链，非常的麻烦。日志记录与错误无关且对调试没有帮助的信息应被视为噪音，记录的原因应是某个调用失败了，而日志中包含了它失败的原因，因此，同一个调用的错误信息，应在日志中完整且连续。



我们在遇到错误的时候，只应该从下面的行为中挑选一种方式去处理：

* 将错误抛给上层
* 自行对错误进行处理，处理完后该错误则无需再抛给上层（如记录日志）





目前go的wrap error在标准库的实现做的不是很好，需要依赖第三方的库，常用的为`github.com/pkg/errors`

* 能方便我们保留原始的堆栈信息
* 同时在不破坏原始错误信息的类型或者值的前提下，附带上一些额外的上下文信息。



## pkg/errors

* 为错误添加上下文

  在与其它库进行协作的时候，考虑使用`errors.Wrap`或者`errors.Wrapf`来保存堆栈信息

  ```go
  func Write(w io.Write, buf []byte) error {
      _, err := w.Write(buf)
      return errors.Wrap(err, "write failed")
  }
  ```

  在最后记录日志错误时，在最顶部的位置，使用`%+v`把堆栈详情记录下来

  

* 在应用代码中，使用`pkg/errors`中的`errors.New`或者`errors.Errorf`返回错误

  在`pkg/errors`中的这两个方法是包含堆栈信息的，而标准库中的`errors.New`则没有这个功能

* 使用`errors.Cause`来获取根错误，来进行错误判定或者类型断言

* 如果你的库是基础库，是会被其他人去使用的，此时你应该尽量返回原始错误而不是使用wrap后的错误，我们尽量是在应用级别的代码去使用wrap

  因为在进行wrap一次之后，如果调用方在wrap一次，在打印堆栈信息的时候就会被打印两次，对于调试没有帮助



## 1.13的error

* `errors.Unwrap`

  我们可以为自定义的error来实现Unwrap方法

  ```go
  func (e *CustomError) UnWrap() error {
      return e.Err
  }
  ```

  通过该形式为`errors.Is`和`errors.As`提供根因检查

  

* 使用`%w`来包装错误

  1.13中可以使用`fmt.Errorf`为错误追加附加信息时，还可以通过`%w`来讲原始错误的值和类型信息保留，效果与`pkg/errors`中的wrap类似，但是，它没有保留调用堆栈信息

  ```go
  if err != nil {
      return fmt.Errorf("error happened: %w", err)
  }
  ```

  

* `errors.Is`

  使用了`%w`来包装的错误，可以通过`errors.Is`来进行错误等值判断

  ```go
  if err != nil {
      if errors.Is(err, MyCustomError) {
          // your action
      }
  }
  ```

  `errors.Is`方法会按照以下步骤运行：

  1. 该error有无实现了`func Is(err, target error)bool`方法，若有，则按照用户自己实现的Is方法进行等值判断
  2. 若没有实现Is方法，则不断调用`errors.Unwrap`来层层获取，直到获取到了错误的根因，再与提供的错误进行判断

  

  因此我们可以自己对自定义的错误类型的Is方法进行扩展

  

* `errors.As`

  使用了`%w`来包装的错误，可以通过`errors.As`来进行错误类型断言

  ```go
  if err != nil {
      if errors.As(err, &MyCustomError{}) {
          // your action
      }
  }
  ```

  和`errors.Is`一样，我们也可以自己对自定义的错误类型的As方法进行扩展



