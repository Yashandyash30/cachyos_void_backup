function mountsurya --description "Mount Surya HPC home directory locally"
    mkdir -p ~/Surya
    if mountpoint -q ~/Surya
        echo "Surya is already mounted at ~/Surya"
    else
        sshfs yashsharma@192.168.4.1:/home/yashsharma ~/Surya -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3
        and echo "Successfully mounted Surya HPC to ~/Surya (visible in Dolphin)"
    end
end
