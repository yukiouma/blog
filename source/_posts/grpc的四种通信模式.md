---
title: gRPC的四种通信模式
date: 2022-04-01 07:44:39
tags: 
- Golang
categories:
- Web开发
---

## 简单RPC

### 描述
> 客户端发送一个请求，然后等待服务端的一次响应

<!-- more -->

### protobuffer 定义
```protobuf
service DemoService {
  rpc SimpleMode(SimpleModeRequest) returns (SimpleModeReply) {};
}

message SimpleModeRequest {
  int32 id = 1;
}

message SimpleModeReply {
  string messgae = 1;
}
```
### 服务端实现模板

```go
func (s *DemoService) SimpleMode(ctx context.Context, in *demo.SimpleModeRequest) (*demo.SimpleModeReply, error) {
	data := s.data[in.Id]
	return &demo.SimpleModeReply{
		Messgae: data,
	}, nil
}
```

### 客户端实现模板

```go
func (c *DemoClient) SimpleMode(ctx context.Context) {
	reply, err := c.c.SimpleMode(ctx, &demo.SimpleModeRequest{Id: 10})
	if err != nil {
		log.Fatalf("SimpleMode Error: %v", err.Error())
	}
	log.Printf("SimpleMode Result: %v", reply)
}
```



## 服务端流模式

### 描述

> 客户端发送一次请求，服务端持续发送多个响应，客户端持续读取多个响应直到没有响应为止

### protobuffer 定义

```protobuf
service DemoService {
  rpc ServerSideStreamMode(ServerSideStreamModeRequest) returns (stream ServerSideStreamModeReply) {};
}

message ServerSideStreamModeRequest {
  int32 id = 1;
}

message ServerSideStreamModeReply {
  string message = 1;
}
```

### 服务端实现模板

```go
func (s *DemoService) ServerSideStreamMode(in *demo.ServerSideStreamModeRequest, stream demo.DemoService_ServerSideStreamModeServer) error {
	for i := in.Id; i < int32(len(s.data)) && i < in.Id+20; i += 2 {
		data := s.data[i]
		if err := stream.Send(&demo.ServerSideStreamModeReply{
			Message: data,
		}); err != nil {
			return err
		}
	}
	return nil
}
```

### 客户端实现模板

```go
func (c *DemoClient) ServerSideStreamMode(ctx context.Context) {
	stream, err := c.c.ServerSideStreamMode(ctx, &demo.ServerSideStreamModeRequest{Id: 20})
	if err != nil {
		log.Fatalf("ServerSideStreamMode Error: %v", err.Error())
	}
	for {
		data, err := stream.Recv()
		if errors.Is(err, io.EOF) {
			return
		}
		if err != nil {
			log.Fatalf("ServerSideStreamMode Error: %v", err.Error())
		}
		log.Printf("ServerSideStreamMode Result: %v", data)
	}
}
```



## 客户端流模式

### 描述

> 客户端发送多个请求，服务端不断接受请求直到客户端没有发送请求位置，最后发送一个响应返回给客户端

### protobuffer 定义

```protobuf
service DemoService {
  rpc ClientSideStreamMode(stream ClientSideStreamModeRequest) returns (ClientSideStreamModeReply) {};
}

message ClientSideStreamModeRequest {
  int32 id = 1;
}

message ClientSideStreamModeReply {
  repeated string message = 1;
}
```

### 服务端实现模板

```go
func (s *DemoService) ClientSideStreamMode(stream demo.DemoService_ClientSideStreamModeServer) error {
	message := make([]string, 0)
	for {
		data, err := stream.Recv()
		if errors.Is(err, io.EOF) {
			return stream.SendAndClose(&demo.ClientSideStreamModeReply{
				Message: message,
			})
		}
		if err != nil {
			return err
		}
		message = append(message, s.data[data.Id])
	}
}
```

### 客户端实现模板

```go
func (c *DemoClient) ClientSideStreamMode(ctx context.Context) {
	stream, err := c.c.ClientSideStreamMode(ctx)
	if err != nil {
		log.Fatalf("ClientSideStreamMode Error: %v", err.Error())
	}
	for _, v := range []int{10, 20, 30, 40, 50} {
		if err := stream.Send(&demo.ClientSideStreamModeRequest{Id: int32(v)}); err != nil {
			log.Fatalf("ClientSideStreamMode Error: %v", err.Error())
		}
	}
	reply, err := stream.CloseAndRecv()
	if err != nil {
		log.Fatalf("ClientSideStreamMode Error: %v", err.Error())
	}
	log.Printf("ClientSideStreamMode Result: %v", reply)
}
```



## 双向流模式

### 描述

> 客户端发送多个请求，服务端不断接受并持续发送多个响应返回给客户端，直到客户端没有更多的请求进来

### protobuffer 定义

```protobuf
service DemoService {
  rpc BothStreamMode(stream BothStreamModeRequest) returns (stream BothStreamModeReply) {};
}

message BothStreamModeRequest {
  int32 id = 1;
}

message BothStreamModeReply {
  string message = 1;
}
```

### 服务端实现模板

```go
func (s *DemoService) BothStreamMode(stream demo.DemoService_BothStreamModeServer) error {
	for {
		data, err := stream.Recv()
		if errors.Is(err, io.EOF) {
			return nil
		}
		if err != nil {
			return err
		}
		message := s.data[data.Id]
		if err := stream.Send(&demo.BothStreamModeReply{Message: message}); err != nil {
			return err
		}
	}
}
```

### 客户端实现模板

```go
func (c *DemoClient) BothStreamMode(ctx context.Context) {
	stream, err := c.c.BothStreamMode(ctx)
	stop := make(chan struct{})
	if err != nil {
		log.Fatalf("BothStreamMode Error: %v", err.Error())
	}
	go func() {
		for {
			data, err := stream.Recv()
			if errors.Is(err, io.EOF) {
				close(stop)
				return
			}
			if err != nil {
				log.Fatalf("BothStreamMode Error: %v", err.Error())
			}
			log.Printf("BothStreamMode Result: %v", data)
		}
	}()
	for _, v := range []int{10, 20, 30, 40, 50} {
		if err := stream.Send(&demo.BothStreamModeRequest{Id: int32(v)}); err != nil {
			log.Fatalf("BothStreamMode Error: %v", err.Error())
		}
	}
	if err := stream.CloseSend(); err != nil {
		log.Fatalf("BothStreamMode Error: %v", err.Error())
	}
	<-stop
}
```

要注意这里

* 客户端要在发送请求之前要先开启一个goroutine持续从流对象种获取数据
* 在发送完毕后需要记得把发送关闭流的信息通知服务端