function unmountsurya --description "Unmount Surya HPC directory"
    if mountpoint -q ~/Surya
        fusermount -u ~/Surya
        and echo "Unmounted ~/Surya"
    else
        echo "~/Surya is not currently mounted"
    end
end
