# 银色仰望 U7 · Codex 启动动画

## 直接使用

解压 `U7-Codex-Boot-Mac.zip` 后双击 `U7 Codex Boot.app`。它播放山路进场动画，同时打开本机 Codex；尾帧等待 Codex 窗口就绪后淡出，按 `Esc` 可跳过。

这是独立启动器。它不修改 Codex、不替换 Dock 图标、不改变现有 U7 壁纸设置。想看动画时请从这个 app 启动 Codex。

## 制作方式

1. `last-silver-u7.jpg` 是本机已有的银色 U7 山路图。
2. 使用内置图像生成工具按 `image-edit-prompt.txt` 去除车辆，得到 `first-empty-road.png`。
3. `make_pipeline.py` 从 `first-last-template.vpipeline` 构造本地 Vpipe 工作流。文字提示词见 `prompt.txt`；运行脚本后会生成包含本机文件路径的 `u7-entrance.vpipeline`。
4. Vpipe Manager + MiniMax-H3-FL2VA-8bit 生成约 5.2 秒的 `u7-entrance-test.mp4`。结尾交叉淡入原始 U7 图片并停留，得到 6.334 秒的 `u7-entrance-final.mp4`。
5. `U7Boot.swift` 使用 AVPlayer 播放视频、打开 bundle ID 为 `com.openai.codex` 的应用，等待其窗口出现，并在结尾淡出到真实窗口。

## 源码重新打包

这台 Mac 上需要 Xcode 命令行工具。修改 `u7-entrance-final.mp4` 后运行：

```sh
zsh build.sh dist
```

启动器是本机临时签名。视频是 960×544、24 fps，原片约 5.2 秒，最终启动视频约 6.3 秒。生成过程中的车牌和部分细节由模型重绘；最后停留画面取自原始 U7 图片。
