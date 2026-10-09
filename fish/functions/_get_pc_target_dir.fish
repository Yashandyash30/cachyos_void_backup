function _get_pc_target_dir
    # Helper function to dynamically translate local mount paths to PC absolute paths
    if string match -q "/mnt/PC_Home*" $PWD
        set target_dir (string replace "/mnt/PC_Home" "/home/void" $PWD)
    else if string match -q "/mnt/PC_Storage*" $PWD
        set target_dir (string replace "/mnt/PC_Storage" "/mnt/Storage" $PWD)
    else if string match -q "/home/void*" $PWD
        set target_dir (string replace "/home/void" "/mnt/Laptop_Home" $PWD)
    else
        set target_dir "/home/void"
    end
    
    echo $target_dir
end
