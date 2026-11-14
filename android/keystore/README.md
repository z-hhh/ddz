# 牌桌固定测试签名

从1.8.1起所有本项目debug/release构建固定引用 `android/keystore/paizhuo.keystore`，不得删除、重新生成或回退到系统debug签名。该文件随完整源码ZIP保存，恢复源码时一并恢复。

- 类型：PKCS12，RSA 2048位，签名算法 SHA256withRSA
- 别名：androiddebugkey
- storePassword：android
- keyPassword：android
- 证书SHA256：1DA269D5F18D161936B8192D837C6319DD70000C746147C0D8525B27A15C8E3C
- 到期：2056-11-05 UTC
- 配置：android/app/build.gradle.kts，paizhuo signingConfig

此为本项目测试分发密钥，口令与源码一起交付；不是商店正式发布密钥。后续安装包的证书SHA256必须与上述值完全一致，两个架构都要核验，才能保证同架构版本可直接覆盖更新。

1.8.0证书不同，首次升级1.8.1需卸载旧版，重置本地设置；自1.8.1起复用本密钥。签名校验：`apksigner verify --print-certs <apk>`。

VFS增量备份保存了同一文件的base64编码。若从增量恢复：`base64 -d paizhuo.keystore.base64 > paizhuo.keystore`，再用上述指纹核验。ZIP中已经是可直接构建的二进制文件。
