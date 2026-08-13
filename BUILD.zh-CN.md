# 构建说明

[English](BUILD.md) | **简体中文**

本文档介绍如何在本机创建并打包 `Balatro3DS.3dsx`。其他构建方式可以参考
[Lovebrew Wiki](https://lovebrew.org)。构建需要安装 devkitPro 及其 `3ds-dev` 软件包，安装方法请参考
[devkitPro Wiki](https://devkitpro.org/wiki/Getting_Started)。

特别感谢 Lovebrew Discord 中的 @natesquared。以下步骤基于其为另一位用户提供的类似构建说明。

## Windows

仓库提供了 `build-msys.sh`，用于在 devkitPro MSYS2 环境中完成构建。请先安装 devkitPro，
并勾选 Nintendo 3DS 开发组件，然后打开 devkitPro MSYS2 终端。

除了 `3ds-dev` 安装的工具外，脚本还需要 `git`、`curl`、`zip` 和 `unzip`。如果缺少这些
MSYS2 工具，请执行：

```sh
pacman -S --needed git curl zip unzip
```

在 devkitPro MSYS2 终端中进入仓库，然后执行构建：

```sh
cd /path/to/Balatro3DS
bash build-msys.sh
```

首次构建时，脚本会下载 LovePotion 3.0.2，并在 `~/balatro3ds-build` 下准备其 CTR romfs。
随后脚本会复制当前工作区、转换所需资源、打包游戏，并将最终文件输出到：

```text
dist/Balatro3DS.3dsx
```

脚本支持以下命令：

```sh
bash build-msys.sh prepare  # 只准备 LovePotion，不构建游戏
bash build-msys.sh build    # 执行完整构建（默认命令）
bash build-msys.sh clean    # 删除构建缓存和 dist 输出
```

更新游戏代码后，再次执行 `bash build-msys.sh` 或 `bash build-msys.sh build` 即可重新打包。
脚本会根据当前工作区重新创建游戏副本，包括尚未提交的修改，并且不会修改项目源码。

## Linux 和 macOS

1. 首先创建一个用于存放所有构建文件的目录。

```sh
mkdir build_dir
cd build_dir
```

2. 打开 [LovePotion GitHub Releases](https://github.com/lovebrew/lovepotion/releases) 的最新版本，
下载名为 `Nintendo.3DS-[xxxxxxx].zip` 的文件，并将它解压到刚才创建的目录中。此时目录结构应如下：

```text
build_dir/
└── Nintendo.3DS-[xxxxxxx]/
    ├── lovepotion.3dsx
    └── lovepotion.elf
```

其中 `xxxxxxx` 是发布页面中使用的一组 7 位提交标识。

3. 克隆 LovePotion 仓库。后续构建需要使用其中的 romfs 目录。

```sh
git clone https://github.com/lovebrew/lovepotion.git lovepotion && rm -rf lovepotion/.git
```

4. 克隆 Balatro3DS 仓库。

```sh
git clone https://github.com/idkhan/Balatro3DS.git Balatro3DS && rm -rf Balatro3DS/.git
```

5. 创建名为 `build` 的目录，将 Balatro3DS 目录复制进去并命名为 `game`。之后生成的文件都放在
这个构建目录中。

```sh
mkdir build
cp -r Balatro3DS build/game
```

此时目录结构应如下：

```text
build_dir/
├── Balatro3DS/
│   └── ...
├── build/
│   └── game/
│       └── ...
├── lovepotion/
│   └── ...
└── Nintendo.3DS-[xxxxxxx]/
    └── ...
```

6. 将图片和字体分别转换为 `.t3x` 和 `.bcfnt` 文件。命令中的 `&& rm $0` 是可选操作，
用于删除原始文件以节省空间。

> [!NOTE]
> 此步骤需要一些时间，请耐心等待。

```sh
find ./build/game -type f -name "*.png" -exec sh -c 'tex3ds -f rgba $0 -o ${0%.png}.t3x && rm $0' {} \;
find ./build/game -type f -name "*.ttf" -exec sh -c 'mkbcfnt $0 -o ${0%.ttf}.bcfnt && rm $0' {} \;
```

7. 转换完成后，创建元数据文件。

> [!NOTE]
> 请使用原始 `Balatro3DS` 目录中的 `icon.png`。`build/game` 中的图标可能已经在上一步转换为
> `.t3x` 文件。

```sh
smdhtool --create "Balatro3DS" "A Remake of Balatro for the 3DS" "Gazpacho" ./Balatro3DS/resources/textures/1x/icon.png ./build/metadata.smdh
```

8. 构建基础 `.3dsx` 文件。此步骤会用到之前取得的 LovePotion romfs。

> [!NOTE]
> 这个文件只是 stub，单独在 3DS 上运行会报错。请将命令中的 `xxxxxxx` 替换为本机实际的
> 目录名称。

> [!WARNING]
> 必须使用 `Nintendo.3DS-[xxxxxxx]` 目录中的 `lovepotion.elf`，不要使用 `lovepotion.3dsx`。

```sh
3dsxtool Nintendo.3DS-[xxxxxxx]/lovepotion.elf ./build/base.3dsx --smdh=./build/metadata.smdh --romfs=./lovepotion/platform/ctr/romfs
```

9. 进入 `game` 目录，使用 `zip` 打包游戏。

```sh
cd ./build/game
zip -r ../balatro.love .
```

10. 最后，将 stub 与游戏内容拼接成最终的 `.3dsx` 文件。

```sh
cd ..
cat base.3dsx balatro.love > Balatro3ds.3dsx
```
