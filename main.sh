#! /bin/bash

DEBIAN_FRONTEND=noninteractive


# Get build deps
apt-get build-dep ./ -y


# Build ALVR
git clone https://github.com/alvr-org/ALVR --recursive -b v20.1.0
cd ./ALVR
export CARGO_PROFILE_RELEASE_LTO=true
export RUSTUP_TOOLCHAIN=stable
export CARGO_TARGET_DIR=target
sed -i 's:../../../lib64/libalvr_vulkan_layer.so:libalvr_vulkan_layer.so:' alvr/vulkan_layer/layer/alvr_x86_64.json
cargo fetch --locked --target "x86_64-unknown-linux-gnu"
export ALVR_ROOT_DIR=/usr
export ALVR_LIBRARIES_DIR="$ALVR_ROOT_DIR/lib/x86_64-linux-gnu"
export ALVR_OPENVR_DRIVER_ROOT_DIR="$ALVR_LIBRARIES_DIR/steamvr/alvr/"
export ALVR_VRCOMPOSITOR_WRAPPER_DIR="$ALVR_LIBRARIES_DIR/alvr/"
export FIREWALL_SCRIPT_DIR="$ALVR_ROOT_DIR/share/alvr/"
cargo run --release --frozen -p alvr_xtask -- prepare-deps --platform linux
cargo build \
	--frozen \
	--release \
	-p alvr_server \
	-p alvr_dashboard \
	-p alvr_vulkan_layer \
	-p alvr_vrcompositor_wrapper
for res in 16x16 32x32 48x48 64x64 128x128 256x256; do
	mkdir -p "icons/hicolor/${res}/apps/"
	convert 'alvr/dashboard/resources/dashboard.ico' -thumbnail "${res}" -alpha on -background none -flatten "./icons/hicolor/${res}/apps/alvr.png"
done
mkdir -p ../alvr
cp -rvf ../debian ../alvr/

# Make ALVR Dir
install -Dm644 LICENSE -t "../alvr/usr/share/licenses/alvr/"
install -Dm755 target/release/alvr_dashboard -t "../alvr/usr/bin/"

# vrcompositor wrapper
install -Dm755 target/release/alvr_vrcompositor_wrapper "../alvr/usr/lib/x86_64-linux-gnu/alvr/vrcompositor-wrapper"

# OpenVR Driver
install -Dm644 target/release/libalvr_server.so "../alvr/usr/lib/x86_64-linux-gnu/steamvr/alvr/bin/linux64/driver_alvr_server.so"
install -Dm644 alvr/xtask/resources/driver.vrdrivermanifest -t "../alvr/usr/lib/x86_64-linux-gnu/steamvr/alvr/"

# Vulkan Layer
install -Dm644 target/release/libalvr_vulkan_layer.so -t "../alvr/usr/lib/x86_64-linux-gnu/"
install -Dm644 alvr/vulkan_layer/layer/alvr_x86_64.json -t "../alvr/usr/share/vulkan/explicit_layer.d/"

# Desktop
install -Dm644 packaging/freedesktop/alvr.desktop -t "../alvr/usr/share/applications"

# Icons
install -d ../alvr/usr/share/icons/hicolor/{16x16,32x32,48x48,64x64,128x128,256x256}/apps/
cp -ar icons/* ../alvr/usr/share/icons/

# Firewall
install -Dm644 "packaging/firewall/alvr-firewalld.xml" "../alvr/usr/lib/x86_64-linux-gnu/firewalld/services/alvr.xml"
install -Dm644 "packaging/firewall/ufw-alvr" -t "../alvr/etc/ufw/applications.d/"

install -Dm755 packaging/firewall/alvr_fw_config.sh -t "../alvr/usr/share/alvr/"

cd ../alvr

# Build package
dpkg-buildpackage --no-sign

# Move the debs to output
cd ../
mkdir -p ./output
mv ./*.deb ./output/
