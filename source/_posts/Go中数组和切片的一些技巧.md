---
title: Go中数组和切片中的一些小技巧
date: 2021-10-28 00:04:20
tags: 
- Golang
categories:
- Web开发
---

## 参考文章
[Go语言高级编程(Advanced Go Programming)](https://books.studygolang.com/advanced-go-programming-book/ch1-basic/ch1-03-array-string-and-slice.html)

## 数组

1. Go中的数组是一个完整的值而不是指向数组头部元素的指针，所以一个数组遍历被复制或者被传递的时候是会复制整个数组，数组较大的时候复制和赋值的开销也会较大。为了避免复制数组带来的开销，可以传递一个指向数组的指针，但是数组指针并不是数组。 

   ```go
   import "fmt"
   
   func main() {
   	a := [...]int{1, 2, 3, 4}
   	b := &a
   	fmt.Println(b[0])
   }
   ```
<!-- more -->
   

2. 一个长度为0的数组，实际上对内存的占用也会是0，因此我们可以通过下面的方式，来实现没有付出额外的内存代价，进行了快速的迭代操作

   ```go
   import "fmt"
   
   func main() {
   	var times [5][0]int
   	for range times {
   		fmt.Println("hi~")
   	}
   }
   ```

   上面的一段代码声明了一个长度为5，每个元素都是一个空数组的数组，该数组内的每个元素对于内存的占用都是0

   

3. 我们可以通过声明接口数组，来将不同类型的数组都放入数组内

   ```go
   package main
   
   import (
   	"fmt"
   	"time"
   )
   
   func main() {
   	var element = [...]interface{}{123, "hello world", time.Now()}
   	for _, v := range element {
   		fmt.Println(v)
   	}
   }
   
   ```

   



## 切片

1. 在尾部追加元素

   ```go
   func main() {
   	times := [5][0]int{}
   	a := make([]int, 0, 10)
   	for range times {
   		a = append(a, int(time.Now().Unix()))
   	}
   	fmt.Printf("%#v\n", a)
   }
   ```

   

2. 在头部追加元素

   ```go
   func main() {
   	times := [5][0]int{}
   	a := make([]int, 0, 10)
   	for range times {
   		a = append([]int{int(time.Now().Unix())}, a...)
   	}
   	fmt.Printf("%#v\n", a)
   }
   ```

   在头部追加元素会导致内存的重新分配，导致已有的元素全部复制一次，因此头部追加的操作性能一般比尾部追加的操作要差

   

3. 使用copy和append配合可以避免创建中间的临时切片，完成添加元素的操作

   比如我们需要在切片中间的第i个未知上追加新的内容

   使用append链式操作，这种情况下会有创建临时切片

   ```go
   func main() {
   	a := make([]int, 0, 10)
   	a = append(a, []int{1, 2, 3, 4, 5}...)
   	// 在第3位中插入一个99
   	a = append(a[:3], append([]int{99}, a[3:]...)...)
   	fmt.Printf("%#v\n", a)
   }
   ```

   使用append配合从copy操作，我们就可以避免临时切片的创建

   ```go
   func main() {
   	a := make([]int, 0, 6)
   	a = append(a, []int{1, 2, 3, 4, 5}...)
   	// 在第3位中插入一个99
   	a = append(a, 0)
   	copy(a[3+1:], a[3:])
   	a[3] = 99
   	fmt.Printf("%#v\n", a)
   }
   ```

   先在a后面追加一个元素0，然后将第3为后面的元素全部往后移动一位，此时切片值为[1， 2， 3， 4， 4， 5]，最后再替换掉第三位的4变为99

   

4. 切片元素的删除

   从尾部位置删除，直接修改指针中的len即可

   ```go
   a = []int{1, 2, 3}
   a = a[:len(a)-1]   // 删除尾部1个元素
   a = a[:len(a)-N]   // 删除尾部N个元素
   ```

   

   从头部位置删除，则有两种操作方法：

   移动数据指针

   ```go
    = []int{1, 2, 3}
   a = a[1:] // 删除开头1个元素
   a = a[N:] // 删除开头N个元素
   ```

   不移动指针，使用append或者copy原地完成

   使用append

   ```go
   a = []int{1, 2, 3}
   a = append(a[:0], a[1:]...) // 删除开头1个元素
   a = append(a[:0], a[N:]...) // 删除开头N个元素
   ```

   使用copy

   ```go
   a = []int{1, 2, 3}
   a = a[:copy(a, a[1:])] // 删除开头1个元素
   a = a[:copy(a, a[N:])] // 删除开头N个元素
   ```

    对于删除中间的元素，需要对剩余的元素进行一次整体挪动，同样可以用`append`或`copy`原地完成 

   ```go
   a = []int{1, 2, 3, ...}
   
   a = append(a[:i], a[i+1:]...) // 删除中间1个元素
   a = append(a[:i], a[i+N:]...) // 删除中间N个元素
   
   a = a[:i+copy(a[i:], a[i+1:])]  // 删除中间1个元素
   a = a[:i+copy(a[i:], a[i+N:])]  // 删除中间N个元素
   ```

   

   

5. 避免切片内存泄漏

   切片操作不会复制底层的数据，底层的数据会被保存再内存中，直到它不再被引用。但有时候很可能因为一个小的内存引用导致整个底层的数组处于被使用的状态，这回导致GC延迟对该底层数组的回收

   ```go
   func extract() []int {
   	a := make([]int, 0, 100)
   	for i := 0; i < 100; i++ {
   		a = append(a, i)
   	}
   	return a[:10]
   }
   ```

   我们定义了个方法，方法内先生成了一个元素从0到99的切片，然后我们截取切片前10个元素返回。切片的底层是0-99共99个元素，由于返回的是该切片的指针，返回时底层数组仍然处于被该指针引用的状态，因此离开该函数时这100个底层元素都无法被GC马上回收，造成了内存泄漏

   为了修复这个问题，我们应该采取以下方法

   ```go
   func extract() []int {
   	a := make([]int, 0, 100)
   	for i := 0; i < 100; i++ {
   		a = append(a, i)
   	}
   	return append([]int{}, a[:10]...)
   }
   ```

   我们将底层的10个元素复制过来，形成一个新的切片，然后返回新的切片。新的切片底层只有10个元素，然后函数结束后，原先的100个元素的切片因为丢失了引用，因此回马上被GC回收

   

   在删除切片内元素的时候同意会遇到类似的问题

   比如我们移除尾部的元素的时候

   ```go
   var a []*int{ ... }
   a = a[:len(a)-1]    
   ```

   被删除的最后一个元素依然被引用, 可能导致GC操作被阻碍，我们可以在完成操前，将需要移除的尾部元素设置为nil，然后再执行操作，这样可以保证GC发现需要回收的对象

   ```go
   var a []*int{ ... }
   a[len(a)-1] = nil // GC回收最后一个元素内存
   a = a[:len(a)-1]  // 从切片删除最后一个元素
   ```

   