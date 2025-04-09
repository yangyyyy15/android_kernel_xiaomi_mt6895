测试红米Note11 T Pro+可以使用,感谢作者!

# 使用github action编译,生成release要使用 release.yml
# 自定义内核设置 修改 arch/arm64/configs/gki_defconfig
    目前去掉kernelsu 后续改用apatch ,开启已知的ftrace ebpf kallsysm kprobes 功能

# 启示是编译出来的内核文件一定要签名,ramdisk 可以解包重打包google的通用文件

# 仓库的 Settings里面要设置一个RSA私钥BOOT_SIGN_KEY
    在 GitHub 仓库中，点击 "Settings" 标签
    在左侧边栏找到 "Secrets and variables" → "Actions"
    点击 "New repository secret"
    名称填写 "BOOT_SIGN_KEY"
    值填入你的 RSA 私钥（如果没有，可以使用 OpenSSL 生成一个）
```
openssl genrsa -out testkey_rsa2048.pem 2048
cat testkey_rsa2048.pem
```
    第一个命令会生成一个 2048 位的 RSA 私钥并保存到 testkey_rsa2048.pem 文件中。
    第二个命令会显示私钥的内容，你需要复制所有输出的内容(包括BEGIN和END行)。
    然后将这个内容粘贴到 GitHub 仓库的 Secret 值中。确保包含了整个私钥，包括 "-----BEGIN RSA PRIVATE KEY-----" 和 "-----END RSA PRIVATE KEY-----" 这两行。
    这个密钥只是用于开发测试，如果是生产环境，请使用更安全的密钥管理方式。
# 本地编译尝试,纯初学者
