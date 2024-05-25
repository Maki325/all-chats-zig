ZIG_BUILD_SUMMARY_FLAG="--summary all"

if [[ "$*" == *"--soff"* ]]
then
  ZIG_BUILD_SUMMARY_FLAG=""
fi

zig build $ZIG_BUILD_SUMMARY_FLAG && ./zig-out/bin/combining-chats
