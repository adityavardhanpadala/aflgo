FROM ubuntu:20.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C
ENV PATH="/usr/local/bin:$PATH"

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    make \
    cmake \
    ninja-build \
    git \
    binutils-gold \
    binutils-dev \
    curl \
    wget \
    python3 \
    python3-dev \
    python3-pip \
    pkg-config \
    autoconf \
    automake \
    libtool-bin \
    gawk \
    libboost-all-dev \
    && rm -rf /var/lib/apt/lists/*

# Create and set working directory
WORKDIR /aflgo-build

# Copy only the necessary files first
COPY afl-2.57b ./afl-2.57b/
COPY instrument ./instrument/
COPY distance ./distance/

# Build and install LLVM and Clang
RUN cd instrument && \
    mkdir -p llvm_tools && \
    cd llvm_tools && \
    wget -O llvm-11.0.0.src.tar.xz https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/llvm-11.0.0.src.tar.xz && \
    tar -xf llvm-11.0.0.src.tar.xz && \
    mv llvm-11.0.0.src llvm && \
    wget -O clang-11.0.0.src.tar.xz https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/clang-11.0.0.src.tar.xz && \
    tar -xf clang-11.0.0.src.tar.xz && \
    mv clang-11.0.0.src clang && \
    wget -O compiler-rt-11.0.0.src.tar.xz https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/compiler-rt-11.0.0.src.tar.xz && \
    tar -xf compiler-rt-11.0.0.src.tar.xz && \
    mv compiler-rt-11.0.0.src compiler-rt && \
    mkdir -p build && \
    cd build && \
    cmake -G "Ninja" \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_TARGETS_TO_BUILD="X86" \
        -DLLVM_BINUTILS_INCDIR=/usr/include \
        -DLLVM_ENABLE_PROJECTS="clang;compiler-rt" \
        -DLLVM_BUILD_TESTS=OFF \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_BUILD_BENCHMARKS=OFF \
        -DLLVM_INCLUDE_BENCHMARKS=OFF \
        ../llvm && \
    ninja && \
    ninja install && \
    rm -rf /aflgo-build/instrument/llvm_tools/*.tar.xz

# Install LLVMgold in bfd-plugins
RUN mkdir -p /usr/lib/bfd-plugins && \
    cp /usr/local/lib/libLTO.so /usr/lib/bfd-plugins && \
    cp /usr/local/lib/LLVMgold.so /usr/lib/bfd-plugins

# Install Python dependencies
RUN python3 -m pip install networkx pydot pydotplus

# Set environment variables for building AFLGo
ENV CXX=clang++
ENV CC=clang
ENV LLVM_CONFIG=llvm-config

# Build AFLGo components
RUN cd afl-2.57b && make clean all && \
    cd ../instrument && make clean all && \
    cd ../distance/distance_calculator && \
    cmake ./ && \
    cmake --build ./

# Clean up unnecessary files
RUN rm -rf /aflgo-build/instrument/llvm_tools/build

COPY examples ./examples/

RUN apt-get update && apt-get install -y parallel

# Set default command
CMD ["/bin/bash"]
