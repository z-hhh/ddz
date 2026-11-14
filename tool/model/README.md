# DouZero 离线模型复现

在应用根目录执行；本次环境为 Python 3.13、CPU PyTorch 2.15.0+cpu、numpy 2.5.4、Flutter 自带 Dart 3.14.0。应用运行不需要 Python 或 PyTorch。

```sh
python3 -m venv .model-venv
.model-venv/bin/pip install -r tool/model/requirements.txt --extra-index-url https://download.pytorch.org/whl/cpu
.model-venv/bin/python tool/model/convert_douzero.py
dart run tool/model/verify.dart
dart compile exe tool/model/benchmark.dart -o /tmp/douzero-benchmark
/tmp/douzero-benchmark 240 /tmp/benchmark.json
dart compile exe tool/model/worker_profile.dart -o /tmp/douzero-profile
/tmp/douzero-profile
flutter test
flutter analyze --no-fatal-infos
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
```

转换脚本下载锁定版本镜像并强制检查三个 checkpoint 的 SHA256；也可传 `--weights /path/to/checkpoints` 使用同名本地文件。原始 checkpoint 不包含在源码压缩包中，转换后完整 Float32 权重已包含，构建与运行不需下载模型。转换保留原始 LSTM 和全部全连接层，只转置存储顺序。

上游观测与输出对照：

```sh
git clone https://github.com/kwai/DouZero /tmp/DouZero
git -C /tmp/DouZero checkout 718a5c920bf3361e34178a38f3b80458e176b351
python tool/model/verify_observations.py --upstream /tmp/DouZero --weights /path/to/checkpoints
```

最后一条脚本默认将报告写入应用根目录的 ../../dist，请预先创建该目录；48 个局面保存在 observation_traces.json。benchmark 会重新生成这些局面。基准 JSON/JSONL 包含每局种子及完整牌序；120 个种子各做地主/农民两局，地主座位轮换，固定叫3分排除叫分差异。大师农民局两位农民均使用模型，结果是队伍胜率。实际游戏叫分仍使用旧规则。候选由原引擎生成（沿用带牌组合最多300项的枚举限制），不宣称穷举所有数学上可能的带牌组合。

新安装默认普通，大师需手动选择并持久化；所有模型计算在持久 isolate 中进行。输入仅含自身手牌和公开信息。模型分值转换为 (value+1)/2 后截断到 [0,1]，作为未校准的胜率估计用于排序。模型加载/推理失败会明确提示并暂停，不会静默改用规则 AI。模型来源、许可证、原始和转换后哈希见 assets/models/manifest.json 和 assets/licenses。
