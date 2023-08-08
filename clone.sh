#这是一个Shebang，指定了脚本要使用的解释器，这里是Bash。
#!/bin/bash

#这行设置了一些选项来控制脚本的行为：
#-E: 如果脚本中的任何命令出错，脚本将立即退出。
#-e: 如果任何命令的退出状态非零，脚本将立即退出。
#-u: 如果使用了未定义的变量，脚本将立即退出。
#-o pipefail: 如果管道中的任何命令失败，脚本将立即退出。
set -Eeuox pipefail

#创建一个目录
mkdir -p /repositories/"$1"
cd /repositories/"$1"
#在当前目录下初始化一个新的Git仓库
git init
#将一个名为"origin"的远程仓库添加到当前Git仓库中，远程仓库的URL是脚本的第二个参数
git remote add origin "$2"
#从"origin"远程仓库中获取指定的分支（脚本的第三个参数），并且只获取最近的一次提交历史（深度为1）
git fetch origin "$3" --depth=1
#将当前分支重置到指定的提交（脚本的第三个参数），使用--hard选项会将工作目录和暂存区的内容全部重置为指定提交的内容
git reset --hard "$3"
#删除当前目录下的.git目录，这是Git仓库的元数据目录，删除它将使当前目录不再是一个Git仓库
rm -rf .git