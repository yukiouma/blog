---
title: Installing multiple Go versions
date: 2022-09-07 14:32:33
tags: 
- installation
categories:
- Golang
---

## Foreword

Usually, we install a specified version of golang sdk (such as go1.18.4). But we might want to install the other version for study or work purposes, and keep all the sdk versions in our computer.
<!-- more -->

## Assumption
We have already installed go 1.18.4 in our computer, and we want to install 1.18.6 in the same time
```bash
$ go version
go version go1.18.4 linux/amd64
```

Current GOROOT and GOPATH
```bash
$ go env GOROOT
/usr/local/go
$ go env GOPATH
/root/go
```

## Steps

### install the binary file

```bash
$ go install golang.org/dl/go1.18.6@latest
go: downloading golang.org/dl v0.0.0-20220907140016-191c3420d549
```

Try to call go1.18.6 by check its version:
```bash
$ go1.18.6 version
go1.18.6: not downloaded. Run 'go1.18.6 download' to install to /root/sdk/go1.18.6
```

Failed to check the version, but we can see go1.18.6 executable binary file has been download in our computer, let's find out where it is:
```bash
$ which go1.18.6
/root/go/bin/go1.18.6
```

### Download the libaray
```bash
$ go1.18.6 download
Downloaded   0.0% (    16384 / 141879729 bytes) ...
Downloaded   1.7% (  2375664 / 141879729 bytes) ...
Downloaded   2.7% (  3817456 / 141879729 bytes) ...
Downloaded   7.4% ( 10469376 / 141879729 bytes) ...
Downloaded  16.7% ( 23658416 / 141879729 bytes) ...
Downloaded  22.6% ( 32128880 / 141879729 bytes) ...
Downloaded  23.4% ( 33144624 / 141879729 bytes) ...
Downloaded  24.9% ( 35323648 / 141879729 bytes) ...
Downloaded  29.9% ( 42368736 / 141879729 bytes) ...
Downloaded  33.0% ( 46874304 / 141879729 bytes) ...
Downloaded  35.5% ( 50364032 / 141879729 bytes) ...
Downloaded  36.6% ( 51871424 / 141879729 bytes) ...
Downloaded  38.2% ( 54148784 / 141879729 bytes) ...
Downloaded  39.6% ( 56196800 / 141879729 bytes) ...
Downloaded  42.9% ( 60849712 / 141879729 bytes) ...
Downloaded  44.6% ( 63258144 / 141879729 bytes) ...
Downloaded  47.1% ( 66895376 / 141879729 bytes) ...
Downloaded  53.9% ( 76529088 / 141879729 bytes) ...
Downloaded  56.4% ( 79953344 / 141879729 bytes) ...
Downloaded  60.1% ( 85327232 / 141879729 bytes) ...
Downloaded  62.0% ( 87981424 / 141879729 bytes) ...
Downloaded  63.8% ( 90471760 / 141879729 bytes) ...
Downloaded  64.6% ( 91684240 / 141879729 bytes) ...
Downloaded  69.7% ( 98860304 / 141879729 bytes) ...
Downloaded  77.7% (110263488 / 141879729 bytes) ...
Downloaded  79.9% (113310928 / 141879729 bytes) ...
Downloaded  81.4% (115457168 / 141879729 bytes) ...
Downloaded  83.0% (117800128 / 141879729 bytes) ...
Downloaded  83.5% (118488224 / 141879729 bytes) ...
Downloaded  84.8% (120257680 / 141879729 bytes) ...
Downloaded  87.9% (124697744 / 141879729 bytes) ...
Downloaded  90.0% (127695936 / 141879729 bytes) ...
Downloaded  95.4% (135412736 / 141879729 bytes) ...
Downloaded  98.4% (139557856 / 141879729 bytes) ...
Downloaded 100.0% (141879729 / 141879729 bytes)
Unpacking /root/sdk/go1.18.6/go1.18.6.linux-amd64.tar.gz ...
Success. You may now run 'go1.18.6'
```

Now we have downloaded the library of go1.18.6 completely, let's try to check its version again:
```bash
$ go1.18.6 version
go version go1.18.6 linux/amd64
```
And it works.

### Checkout GOPATH and GOROOT

```bash
$ go1.18.6 env GOPATH
/root/go
$ go1.18.6 env GOROOT
/root/sdk/go1.18.6
```

We can see GOPATH is the same as the go1.18.4, but GOROOT has changed to another place

## Uninstall Addtional Versions

1. Remove libaray
```bash
rm -rf /root/sdk/go1.18.6
```

2. Remove the binary file
```bash
rm -rf /root/go/bin/go1.18.6
```

## Reference
[Managing Go installations](https://go.dev/doc/manage-install)