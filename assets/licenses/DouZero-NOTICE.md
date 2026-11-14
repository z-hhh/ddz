# DouZero attribution and model provenance

Original project: DouZero, Kwai (Kuaishou) AI Platform & Texas A&M University.
Repository: https://github.com/kwai/DouZero
Code commit: 718a5c920bf3361e34178a38f3b80458e176b351
License: Apache License 2.0; complete original text in DouZero-APACHE-2.0.txt.
No upstream NOTICE file was present in that tree.
Apache-2.0 permits commercial use and redistribution subject to its terms,
including providing the license, retaining relevant notices and marking changes.
No trademark endorsement or additional warranty is claimed.

Official README does NOT bundle pretrained weights: baselines contains a placeholder.
It links Google Drive and Baidu Netdisk. At retrieval on 2026-11-14 UTC, the
Google Drive folder returned HTTP 404; Baidu redirected to an extraction/login flow.

Downloaded model: DouZero-WP, three role-specific pretrained checkpoints.
Mirror: https://huggingface.co/palemoky/douzero-baselines
Mirror commit: 57b3914046c2a0877016b8b8830fd07cf5b0ba08
Mirror model card explicitly declares apache-2.0 and identifies these as upstream
baseline weights. Its original text is included as DouZero-mirror-README.md.

Verification: exact upstream state_dict names/shapes and parameter counts; strict
load_state_dict; finite weights; SHA256 of source/converted files recorded in
assets/models/manifest.json. Dart inputs and scores checked against pinned upstream
get_obs and PyTorch forward. This is structural/numerical verification; official
weights were inaccessible, so bit-for-bit identity to the unavailable official
Google/Baidu files is NOT claimed.

Changes made by this app:
- Converted .ckpt tensors to DZ01 Float32 little-endian binary (no quantization).
- Transposed matrix storage; shared first-layer state calculation across candidates.
- Reimplemented full LSTM + five 512-unit ReLU layers + linear output in pure Dart.
- Mapped app card IDs/public history to the official imperfect-information encoding.
- Current engine, not DouZero's move generator, supplies/revalidates all candidates.

Original PyTorch network source is retained in tool/model/upstream_models.py.
Conversion is reproducible using tool/model/convert_douzero.py with pinned downloads
and source SHA256 enforcement. Runtime is fully offline and ships all weights.
