FLAGS="--summary all"

zig build $FLAGS && ./zig-out/bin/combining-chats
