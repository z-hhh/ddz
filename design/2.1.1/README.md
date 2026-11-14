# 2.1.1 首页素材

标题与空白牌匾：Comma image.generate / gpt-image-2；原图与提示词见随版素材包。
标题中文字人工逐字核对：斗、地、主。
按钮功能字用 Noto Sans CJK SC Bold（OFL 1.1）确定性烘焙为透明 WebP：单机、创建房间、加入房间、设置、难度、规则。字图保持比例，空白底图九宫格切片，运行时不依赖系统字体。许可原文随 assets/licenses/Noto-CJK-OFL.txt。
源图处理脚本 prepare.py 原始路径以素材包目录为准：originals/ 与 prepare.py 同目录，其父目录下 source/doudizhu 为应用目录。

按钮独立保留语义标签、点击热区、90ms 非阻塞按下反馈、下移2px、禁用透明度0.38且无点击回调。禁用态截图是组件验收夹具，并非新增的业务限制。
首页设置进入音效与节奏，难度进入原设置页，规则进入规则页。其他游戏逻辑不变。
