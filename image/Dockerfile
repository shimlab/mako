FROM ubuntu:24.04

LABEL org.opencontainers.image.source=https://github.com/shimlab/mako

ENV LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common ca-certificates wget curl gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install R-base-core
RUN wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc \
    && add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"

# # Pin r2u packages to the top
# RUN echo "Package: *" > /etc/apt/preferences.d/99cranapt && \
#     echo "Pin: release o=CRAN-Apt Project" >> /etc/apt/preferences.d/99cranapt && \
#     echo "Pin: release l=CRAN-Apt Packages" >> /etc/apt/preferences.d/99cranapt && \
#     echo "Pin-Priority: 700"  >> /etc/apt/preferences.d/99cranapt

# Install dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    # general dependencies
    r-base-core python3 python3-pip samtools tabix \
    build-essential libcurl4-openssl-dev libxml2-dev \
    libssl-dev zlib1g-dev libbz2-dev liblzma-dev libpcre2-dev \
    # packages
    # r-cran-tidyverse r-cran-duckdb r-cran-duckplyr r-cran-lme4 r-cran-lmertest r-cran-optparse \
    && rm -rf /var/lib/apt/lists/*

# NOTE:
# "awk, date, grep, ps, sed, tail, tee" are all necessary for Nextflow task reporting to work:
#   https://www.nextflow.io/docs/latest/reports.html#id2
# This line should be uncommented if using a base image that does not include these utilities.
# RUN apt-get install -y ...


COPY python_requirements.txt .
RUN pip install --break-system-packages -r python_requirements.txt

# install Modkit v0.5.0
RUN wget "https://github.com/nanoporetech/modkit/releases/download/v0.5.0/modkit_v0.5.0_u16_x86_64.tar.gz" -O modkit.tar.gz \
    && mkdir modkit && tar -xzf modkit.tar.gz --strip-components=1 -C modkit && rm modkit.tar.gz

# We will use the official ONT Dorado Docker images at https://hub.docker.com/r/nanoporetech/dorado/, which are
# prebuilt and can save on image build time and size.

# install R dependencies
COPY install_R_dependencies.R .
RUN Rscript install_R_dependencies.R

# move files to PATH
RUN ln -s $(realpath modkit/modkit) /usr/local/bin/modkit

# install duckdb
RUN curl https://install.duckdb.org | sh && \
    cp ~/.duckdb/cli/latest/duckdb /usr/local/bin/