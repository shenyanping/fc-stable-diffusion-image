#从alpine/git:2.36.2镜像作为下载阶段的基础镜像
FROM alpine/git:2.36.2 as download
#将本地的clone.sh文件复制到镜像内的/clone.sh路径。
COPY clone.sh /clone.sh
#在镜像内执行clone.sh脚本，克隆taming-transformers仓库，并删除指定的文件。
RUN . /clone.sh taming-transformers https://github.com/CompVis/taming-transformers.git 24268930bf1dce879235a7fddd0b2355b84d7ea6 \
  && rm -rf data assets **/*.ipynb
#在镜像内执行clone.sh脚本，克隆stable-diffusion-stability-ai仓库，并删除指定的文件。
RUN . /clone.sh stable-diffusion-stability-ai https://github.com/Stability-AI/stablediffusion.git 47b6b607fdd31875c9279cd2f4f16b92e4ea958e \
  && rm -rf assets data/**/*.png data/**/*.jpg data/**/*.gif
#在镜像内执行clone.sh脚本，克隆CodeFormer仓库，并删除指定的文件。
RUN . /clone.sh CodeFormer https://github.com/sczhou/CodeFormer.git c5b4593074ba6214284d6acd5f1719b6c5d739af \
  && rm -rf assets inputs
#在镜像内执行clone.sh脚本，克隆BLIP仓库。
RUN . /clone.sh BLIP https://github.com/salesforce/BLIP.git 48211a1594f1321b00f14c9f7a5b4813144b2fb9
#在镜像内执行clone.sh脚本，克隆k-diffusion仓库。
RUN . /clone.sh k-diffusion https://github.com/crowsonkb/k-diffusion.git 5b3af030dd83e0297272d861c19477735d0317ec
#在镜像内执行clone.sh脚本，克隆clip-interrogator仓库。
RUN . /clone.sh clip-interrogator https://github.com/pharmapsychotic/clip-interrogator 2486589f24165c8e3b303f84e9dbbea318df83e8


#从alpine:3.17镜像作为xformers阶段的基础镜像。xformers提升图片生成速度
FROM alpine:3.17 as xformers
#在镜像内安装aria2工具。
RUN apk add --no-cache aria2
#使用aria2c下载xformers的whl文件。
RUN aria2c -x 5 --dir / --out wheel.whl 'https://github.com/AbdBarho/stable-diffusion-webui-docker/releases/download/6.0.0/xformers-0.0.21.dev544-cp310-cp310-manylinux2014_x86_64-pytorch201.whl'


#从python:3.10.9-slim镜像作为基础镜像。
FROM python:3.10.9-slim
#设置环境变量DEBIAN_FRONTEND和PIP_PREFER_BINARY。
ENV DEBIAN_FRONTEND=noninteractive PIP_PREFER_BINARY=1

#更新apt并安装所需的软件包
RUN --mount=type=cache,target=/var/cache/apt \
  apt-get update && \
  # we need those
  apt-get install -y fonts-dejavu-core rsync git jq moreutils aria2 \
  # extensions needs those
  ffmpeg libglfw3-dev libgles2-mesa-dev pkg-config libcairo2 libcairo2-dev

#使用aria2c下载torch的whl文件并安装。
RUN --mount=type=cache,target=/cache --mount=type=cache,target=/root/.cache/pip \
  aria2c -x 5 --dir /cache --out torch-2.0.1-cp310-cp310-linux_x86_64.whl -c \
  https://download.pytorch.org/whl/cu118/torch-2.0.1%2Bcu118-cp310-cp310-linux_x86_64.whl && \
  pip install /cache/torch-2.0.1-cp310-cp310-linux_x86_64.whl torchvision --index-url https://download.pytorch.org/whl/cu118


#克隆stable-diffusion-webui仓库并安装所需的Python依赖。 \
#    --mount=type=cache,target=/root/.cache/pip是用于将一个缓存卷挂载到容器中的特殊选项。
#这个选项的作用是将主机上的缓存目录挂载到容器的/root/.cache/pip目录，以便在构建过程中共享和重用缓存数据。这样可以避免每次构建镜像时都重新下载和安装依赖项，提高构建速度。

RUN --mount=type=cache,target=/root/.cache/pip \
  git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
  cd stable-diffusion-webui && \
#  git reset --hard 20ae71faa8ef035c31aa3a410b707d792c8203a3 && \
  pip install -r requirements_versions.txt

#安装xformers的whl文件。
RUN --mount=type=cache,target=/root/.cache/pip  \
  --mount=type=bind,from=xformers,source=/wheel.whl,target=/xformers-0.0.21.dev544-cp310-cp310-manylinux2014_x86_64.whl \
  pip install /xformers-0.0.21.dev544-cp310-cp310-manylinux2014_x86_64.whl

#设置环境变量ROOT为/stable-diffusion-webui。
ENV ROOT=/stable-diffusion-webui

#从download阶段的镜像复制/repositories目录到ROOT/repositories目录。
COPY --from=download /repositories/ ${ROOT}/repositories/
#在ROOT目录下创建interrogate目录，并将clip-interrogator仓库的数据复制到interrogate目录。
RUN mkdir ${ROOT}/interrogate && cp ${ROOT}/repositories/clip-interrogator/data/* ${ROOT}/interrogate
#安装CodeFormer仓库的Python依赖。
RUN --mount=type=cache,target=/root/.cache/pip \
  pip install -r ${ROOT}/repositories/CodeFormer/requirements.txt

#安装pyngrok和其他几个Git仓库的Python依赖。
RUN --mount=type=cache,target=/root/.cache/pip \
  pip install pyngrok \
  git+https://github.com/TencentARC/GFPGAN.git@8d2447a2d918f8eba5a4a01463fd48e45126a379 \
  git+https://github.com/openai/CLIP.git@d50d76daa670286dd6cacf3bcd80b5e4823fc8e1 \
  git+https://github.com/mlfoundations/open_clip.git@bb6e834e9c70d9c27d0dc3ecedeebeaeb1ffad6b

# Note: don't update the sha of previous versions because the install will take forever
# instead, update the repo state in a later step

# TODO: either remove if fixed in A1111 (unlikely) or move to the top with other apt stuff
#安装libgoogle-perftools-dev软件包。
RUN apt-get -y install libgoogle-perftools-dev && apt-get clean
#设置环境变量LD_PRELOAD为libtcmalloc.so。
ENV LD_PRELOAD=libtcmalloc.so

#定义一个SHA参数。
ARG SHA=b6af0a3
#在stable-diffusion-webui目录下执行git操作，并安装所需的Python依赖。
RUN --mount=type=cache,target=/root/.cache/pip \
  cd stable-diffusion-webui && \
  git fetch && \
  git reset --hard ${SHA} && \
  pip install -r requirements_versions.txt

#将当前目录下的所有文件复制到镜像内的/docker路径。
COPY . /docker

#在镜像内执行一系列命令，包括运行Python脚本、重命名文件、修改文件内容和配置Git。
RUN \
  python3 /docker/info.py ${ROOT}/modules/ui.py && \
  mv ${ROOT}/style.css ${ROOT}/user.css && \
  # one of the ugliest hacks I ever wrote \
  sed -i 's/in_app_dir = .*/in_app_dir = True/g' /usr/local/lib/python3.10/site-packages/gradio/routes.py && \
  git config --global --add safe.directory '*'

#设置工作目录为ROOT。
WORKDIR ${ROOT}
#设置环境变量NVIDIA_VISIBLE_DEVICES为all
ENV NVIDIA_VISIBLE_DEVICES=all
#设置环境变量CLI_ARGS为一组参数。
ENV CLI_ARGS="--xformers  --disable-safe-unpickle --no-half-vae --enable-insecure-extension-access --skip-version-check --no-download-sd-model"
#暴露容器的7860端口。
EXPOSE 7860
#设置容器的入口点为entrypoint.sh脚本。
ENTRYPOINT ["/docker/entrypoint.sh"]
#设置容器的默认命令为运行webui.py脚本。
CMD python -u webui.py --listen --port 7860 ${CLI_ARGS}