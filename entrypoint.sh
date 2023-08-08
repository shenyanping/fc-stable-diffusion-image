#这是一个shebang，指定了脚本使用的解释器，这里是bash。
#!/bin/bash

#这行设置了一些选项来控制脚本的行为：
#-E: 如果脚本中的任何命令出错，脚本将立即退出。
#-e: 如果任何命令的退出状态非零，脚本将立即退出。
#-u: 如果使用了未定义的变量，脚本将立即退出。
#-o pipefail: 如果管道中的任何命令失败，脚本将立即退出。
set -Eeuo pipefail

# TODO: move all mkdir -p ?
# 创建目录/mnt/auto/sd/scripts/，如果目录已经存在则不报错。
mkdir -p /mnt/auto/sd/scripts/
# mount scripts individually
#在${ROOT}/scripts/目录下删除所有的符号链接文件。
find "${ROOT}/scripts/" -maxdepth 1 -type l -delete
#复制/mnt/auto/sd/scripts/目录下的文件到${ROOT}/scripts/目录下，保留源文件的时间戳和符号链接。
cp -vrfTs /mnt/auto/sd/scripts/ "${ROOT}/scripts/"
#如果/mnt/auto/sd/config.json文件不存在，则将/docker/config.json复制到/mnt/auto/sd/config.json。
cp -n /docker/config.json /mnt/auto/sd/config.json
#使用jq工具将/mnt/auto/sd/config.json和/docker/config.json合并，并将结果保存到/mnt/auto/sd/config.json文件中。
jq '. * input' /mnt/auto/sd/config.json /docker/config.json | sponge /mnt/auto/sd/config.json

#如果/mnt/auto/sd/ui-config.json文件不存在，则执行下面的操作。
if [ ! -f /mnt/auto/sd/ui-config.json ]; then
#  将空的JSON对象{}写入/mnt/auto/sd/ui-config.json文件中。
  echo '{}' >/mnt/auto/sd/ui-config.json
fi
# 声明一个关联数组MOUNTS。
declare -A MOUNTS
#将/root/.cache映射到/mnt/auto/sd/.cache。
MOUNTS["/root/.cache"]="/mnt/auto/sd/.cache"

#将${ROOT}/models映射到/mnt/auto/sd/models。
MOUNTS["${ROOT}/models"]="/mnt/auto/sd/models"
#将${ROOT}/localizations映射到/mnt/auto/sd/localizations。
MOUNTS["${ROOT}/localizations"]="/mnt/auto/sd/localizations"
#将${ROOT}/configs映射到/mnt/auto/sd/configs。
MOUNTS["${ROOT}/configs"]="/mnt/auto/sd/configs"
#将${ROOT}/extensions-builtin映射到/mnt/auto/sd/extensions-builtin。
MOUNTS["${ROOT}/extensions-builtin"]="/mnt/auto/sd/extensions-builtin"

#将${ROOT}/embeddings映射到/mnt/auto/sd/embeddings。
MOUNTS["${ROOT}/embeddings"]="/mnt/auto/sd/embeddings"
#将${ROOT}/config.json映射到/mnt/auto/sd/config.json。
MOUNTS["${ROOT}/config.json"]="/mnt/auto/sd/config.json"
#将${ROOT}/ui-config.json映射到/mnt/auto/sd/ui-config.json。
MOUNTS["${ROOT}/ui-config.json"]="/mnt/auto/sd/ui-config.json"
# 将${ROOT}/extensions映射到/mnt/auto/sd/extensions。
MOUNTS["${ROOT}/extensions"]="/mnt/auto/sd/extensions"
#将${ROOT}/outputs映射到/mnt/auto/sd/outputs。
MOUNTS["${ROOT}/outputs"]="/mnt/auto/sd/outputs"
# MOUNTS["${ROOT}/javascript"]="/mnt/auto/sd/javascript"
# MOUNTS["${ROOT}/html"]="/mnt/auto/sd/html"

# extra hacks
#将${ROOT}/repositories/CodeFormer/weights/facelib映射到/mnt/auto/sd/.cache。
MOUNTS["${ROOT}/repositories/CodeFormer/weights/facelib"]="/mnt/auto/sd/.cache"

for to_path in "${!MOUNTS[@]}"; do
#  设置shell选项，同第2行
  set -Eeuo pipefail
#  获取当前遍历到的键对应的值（映射的源路径）。
  from_path="${MOUNTS[${to_path}]}"
#  删除目标路径${to_path}。
  rm -rf "${to_path}"
#  如果源路径$from_path不是一个文件，则执行下面的操作。
  if [ ! -f "$from_path" ]; then
#    创建目录$from_path，如果目录已经存在则不报错。
    mkdir -vp "$from_path"
  fi
#  创建目录${to_path}的父目录，如果目录已经存在则不报错。
  mkdir -vp "$(dirname "${to_path}")"
#  创建一个指向源路径${from_path}的符号链接，并将其命名为${to_path}。
  ln -sT "${from_path}" "${to_path}"
#  输出已挂载的源路径的基本名称。
  echo Mounted $(basename "${from_path}")
done
#如果/mnt/auto/sd/startup.sh文件存在，则执行下面的操作。
if [ -f "/mnt/auto/sd/startup.sh" ]; then
#  将当前目录推入目录堆栈，并切换到${ROOT}目录。
  pushd ${ROOT}
#  执行/mnt/auto/sd/startup.sh脚本。
  . /mnt/auto/sd/startup.sh
#  弹出目录堆栈，切换回之前的目录。
  popd
fi
#执行传递给脚本的参数。
exec "$@"
