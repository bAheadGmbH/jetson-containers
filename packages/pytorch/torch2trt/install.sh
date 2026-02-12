#!/usr/bin/env bash
set -ex

cd /opt
git clone --depth=1 https://github.com/NVIDIA-AI-IOT/torch2trt

cd torch2trt
ls -R /tmp/torch2trt
cp /tmp/torch2trt/flattener.py torch2trt


# Install TensorRT Wheel First to ensure libs are present
TRT_WHEEL=$(find /usr -name "tensorrt-*-cp310-*-linux_aarch64.whl" -print -quit)

if [ -f "$TRT_WHEEL" ]; then
    echo "Installing existing TensorRT wheel: $TRT_WHEEL"
    uv pip install "$TRT_WHEEL"
else
    echo "CRITICAL: TensorRT wheel not found. Build cannot proceed."
    exit 1
fi

# Workaround: JetPack 6.2 image is missing DLA compiler and apt repo config
# Manually download and install the package
DLA_DEB="nvidia-l4t-dla-compiler_36.4.7-20250918154033_arm64.deb"
DLA_URL="https://repo.download.nvidia.com/jetson/common/pool/main/n/nvidia-l4t-dla-compiler/${DLA_DEB}"
echo "Downloading missing DLA compiler package..."
if command -v wget >/dev/null 2>&1; then
    wget -q "$DLA_URL" -O "/tmp/$DLA_DEB"
elif command -v curl >/dev/null 2>&1; then
    curl -sL "$DLA_URL" -o "/tmp/$DLA_DEB"
else
    echo "Error: Neither wget nor curl found. Cannot download DLA compiler."
    exit 1
fi
echo "Installing DLA compiler (extracting to bypass deps)..."
dpkg -x "/tmp/$DLA_DEB" /
ldconfig
rm "/tmp/$DLA_DEB"

python3 setup.py install --plugins

sed 's|^set(CUDA_ARCHITECTURES.*|#|g' -i CMakeLists.txt
sed 's|Catch2_FOUND|False|g' -i CMakeLists.txt

cmake -B build \
  -DCUDA_ARCHITECTURES=${CUDA_ARCHITECTURES} \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 .

cmake --build build --target install

ldconfig

uv pip install --no-build-isolation onnx-graphsurgeon
