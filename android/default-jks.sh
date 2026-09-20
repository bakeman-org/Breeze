#!/bin/bash

# ====================== 配置区域 ======================
# Android JKS 签名证书文件名
KEYSTORE_NAME="default-android.jks"
# 密钥别名（显式指定，避免依赖keytool默认值，方便统一管理）
ALIAS_NAME="mykey"
# 证书库密码
STORE_PASS="123456"
# 私钥密码
KEY_PASS="123456"
# 证书有效天数
VALID_DAYS=10000
# ======================================================

echo "====================================="
echo "        Android JKS 签名证书生成工具"
echo "        证书库密码/私钥密码：123456"
echo "        密钥别名：${ALIAS_NAME}"
echo "====================================="

# 前置检测：如果旧证书文件存在，直接删除，全新生成
if [ -f "$KEYSTORE_NAME" ]; then
    rm -f "$KEYSTORE_NAME"
    echo -e "\nℹ️  检测到旧证书文件，已自动删除旧 $KEYSTORE_NAME"
fi

# 生成密钥对，显式携带 -alias 参数，屏蔽原生英文报错输出
keytool -genkeypair \
-keystore "$KEYSTORE_NAME" \
-alias "$ALIAS_NAME" \
-keyalg RSA \
-keysize 2048 \
-validity $VALID_DAYS \
-storepass "$STORE_PASS" \
-keypass "$KEY_PASS" \
-dname "CN=Android 开发, OU=开发部, O=本地项目, L=本地, ST=本地, C=CN" 2>/dev/null

GEN_RET=$?

if [ $GEN_RET -eq 0 ]; then
    echo -e "\n====================================="
    echo "✅ 证书文件全新生成完成！"
    echo "文件名称：$KEYSTORE_NAME"
    echo "密钥别名：$ALIAS_NAME"
    echo "统一密码：$STORE_PASS"
    echo "====================================="
else
    echo -e "\n❌ 证书生成失败，错误码 $GEN_RET"
    exit $GEN_RET
fi

# 校验证书信息，验证别名与密码是否匹配
echo -e "\n🔍 正在校验证书信息..."
keytool -list -v \
-keystore "$KEYSTORE_NAME" \
-alias "$ALIAS_NAME" \
-storepass "$STORE_PASS"

if [ $? -ne 0 ]; then
    echo -e "\n❌ 证书校验失败！别名或密码配置有误"
    exit 1
fi

echo -e "\n📝 项目配置使用步骤："
echo "[1] 将 $KEYSTORE_NAME 复制到项目根目录"
echo "[2] Groovy 构建脚本(app/build.gradle)配置："
echo "-----------------------------------------------------"
cat << 'EOF'
android {
    signingConfigs {
        release {
            storeFile file("../default-android.jks")
            storePassword "123456"
            keyAlias "mykey"
            keyPassword "123456"
        }
        debug {
            storeFile file("../default-android.jks")
            storePassword "123456"
            keyAlias "mykey"
            keyPassword "123456"
        }
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
            signingConfig signingConfigs.release
        }
        debug {
            signingConfig signingConfigs.debug
        }
    }
}
EOF

echo -e "\n\n[3] Kotlin DSL 构建脚本(app/build.gradle.kts)配置"
echo "-----------------------------------------------------"
cat << 'EOF'
android {
    signingConfigs {
        create("release") {
            storeFile = file("../default-android.jks")
            storePassword = "123456"
            keyAlias = "mykey"
            keyPassword = "123456"
        }
        create("debug") {
            storeFile = file("../default-android.jks")
            storePassword = "123456"
            keyAlias = "mykey"
            keyPassword = "123456"
        }
    }

    buildTypes {
        getByName("release") {
            minifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("release")
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
EOF

echo -e "\n\n[4] 命令行打包签名APK："
echo "./gradlew assembleDebug   # 生成已签名调试包"
echo "./gradlew assembleRelease # 生成已签名正式包"
echo "====================================="