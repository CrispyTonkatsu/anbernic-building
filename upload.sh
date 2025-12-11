#/usr/bin/env sh

if [ -f ".env" ]; then
  source ".env"
fi

export MUOS_USER="root"
export MUOS_PASS="root"
export TARGET="aarch64-unknown-linux-musl"
export SOURCE="./target/$TARGET/debug/anbernic-building"
export DESTINATION="/mnt/sdcard/Roms/Apps/"

cargo build --target $TARGET

scp $SOURCE "$MUOS_USER@$MUOS_IP:/$DESTINATION"
