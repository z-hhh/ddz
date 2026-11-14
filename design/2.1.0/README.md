# 2.1.0 美术源文件

生成工具：Comma image.generate；返回模型：gpt-image-2。11项提示词及参考关系见 prompts.json。交付的“2.1.0-源图与提示词.zip”包含完整原始PNG，应用 assets/art 为缩小后的 WebP，原生图标与启动页复用新图标，不含外部下载图库。

将源图包的 originals 放到项目外的 art-2.1.0/originals，使用 Pillow 缩放转换。原图、应用图及图标SHA256见 asset-manifest.json。源图和提示词仅是交付文档，不作为应用界面文案展示。

Android manifest 从启动 Activity 设置 sensorLandscape，Flutter main 在 runApp 之前等待双向横屏请求；界面不再在退出对局时解除方向。iOS支持方向也仅保留两种横屏。Flutter首帧截图不等同于Android真机冷启动录像；本次没有可用共享真机。
