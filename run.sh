ZIG_BUILD_SUMMARY_FLAG="--summary all"

if [[ "$*" == *"--soff"* ]]
then
  ZIG_BUILD_SUMMARY_FLAG=""
fi

zig build -freference-trace $ZIG_BUILD_SUMMARY_FLAG && ./zig-out/bin/combining-chats
