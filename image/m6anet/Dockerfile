FROM nvidia/cuda:11.8.0-base-ubuntu22.04

LABEL org.opencontainers.image.source=https://github.com/shimlab/mako

WORKDIR /app
RUN apt-get update && apt-get install -y wget bzip2 build-essential libgl1 libglib2.0-0 && \
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /miniconda.sh && \
    bash /miniconda.sh -b -p /opt/conda && \
    rm /miniconda.sh && \
    rm -rf /var/lib/apt/lists/*
ENV PATH="/opt/conda/bin:$PATH"

RUN apt update && apt install -y libncurses-dev openssl zlib1g-dev git
RUN echo "channels:\n\
  - bioconda\n\
  - conda-forge\n\
  - defaults\n" > /opt/conda/.condarc

RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && \
    conda init

RUN conda create --name m6anet python=3.8 bioconda::samtools bioconda::f5c
SHELL ["conda", "run", "-n", "m6anet", "/bin/bash", "-c"]

RUN pip install git+https://github.com/olliecheng/m6anet.git

