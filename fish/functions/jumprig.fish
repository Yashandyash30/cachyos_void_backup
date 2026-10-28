function jumprig -d "Jump to Rig into current directory"
    echo "Jumping to Rig at $PWD..."
    ssh -t rig "cd '$PWD' && exec fish"
end
