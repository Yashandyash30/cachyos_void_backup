function patch_remote_ide --description 'Pre-sync and patch Antigravity IDE server runtime to ARIES and Surya'
    set -l latest_commit (ls -t /home/void/.antigravity-ide-server/bin/ 2>/dev/null | head -n 1)
    if test -z "$latest_commit"
        echo "No local Antigravity IDE server installations found."
        return 1
    end

    echo "Found local Antigravity IDE server commit: $latest_commit"

    echo "=== 1. Syncing to ARIES ==="
    rsync -az /home/void/.antigravity-ide-server/bin/$latest_commit/ aries:~/.antigravity-ide-server/bin/$latest_commit/
    ssh aries "~/bin/patchelf --set-interpreter ~/local/glibc/usr/lib64/ld-linux-x86-64.so.2 --set-rpath ~/local/glibc/usr/lib64 ~/.antigravity-ide-server/bin/$latest_commit/node && touch ~/.antigravity-ide-server/bin/$latest_commit/node.patched"
    echo "✓ ARIES patched successfully!"

    echo "=== 2. Syncing to Surya HPC ==="
    rsync -az /home/void/.antigravity-ide-server/bin/$latest_commit/ surya:~/.antigravity-ide-server/bin/$latest_commit/
    ssh surya "~/bin/patchelf --set-interpreter ~/local/glibc/usr/lib64/ld-linux-x86-64.so.2 --set-rpath ~/local/glibc/usr/lib64 ~/.antigravity-ide-server/bin/$latest_commit/node && touch ~/.antigravity-ide-server/bin/$latest_commit/node.patched"
    echo "✓ Surya HPC patched successfully!"

    echo "All remote environments ready for native Remote-SSH!"
end
