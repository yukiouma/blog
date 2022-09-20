---
title: Rust Installation
date: 2022-09-20 12:55:24
tags: 
- installation
categories:
- Rust
---


via rustup

```bash
curl https://sh.rustup.rs -sSf | sh
```

<!-- more -->

> all options was set to default

Ensure `$HOME/.cargo/bin` was added in envirement variable `$PATH`
* reboot machine;
* execute `source ~/.profile` manually;


Check you rustc and cargo version
```bash
$ rustc --version
rustc 1.63.0 (4b91a6ea7 2022-08-08)
$ cargo --version
cargo 1.63.0 (fd9c4297c 2022-07-01)
```

## Plugins in VSCode
* rust-analyzer
* Better TOML
* Microsoft C++
* CodeLLDB

## Auto Formatting On Save
1. Open `File->Perferences->Settings`(or using hot key `Ctrl + ,`)
2. Search and select option: "Editor: Format On Save"
3. Turn on this option

## Debug
> make sure plugins `Microsoft C++` and `CodeLLDB` was installed

config `<cargo project root dir>/.vscode/launch.json`
```
{
    // Use IntelliSense to learn about possible attributes.
    // Hover to view descriptions of existing attributes.
    // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "type": "lldb",
            "request": "launch",
            "name": "Debug executable 'greeting'",
            "cargo": {
                "args": [
                    "build",
                    "--bin=greeting",
                    "--package=greeting"
                ],
                "filter": {
                    "name": "greeting",
                    "kind": "bin"
                }
            },
            "args": [],
            "cwd": "${workspaceFolder}"
        },
        {
            "type": "lldb",
            "request": "launch",
            "name": "Debug unit tests in executable 'greeting'",
            "cargo": {
                "args": [
                    "test",
                    "--no-run",
                    "--bin=greeting",
                    "--package=greeting"
                ],
                "filter": {
                    "name": "greeting",
                    "kind": "bin"
                }
            },
            "args": [],
            "cwd": "${workspaceFolder}"
        }
    ]
}
```
Then we can debug project by pressing F5
