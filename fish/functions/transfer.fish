function transfer --description "Transfer files/directories to pc, laptop, or surya via rsync"
    if test (count $argv) -lt 2
        echo "Usage: transfer <pc|laptop|surya|aries> <file1> [file2...] [destination_folder/]"
        echo ""
        echo "Examples:"
        echo "  transfer surya mesasdk-x86_64-linux-23.7.3.tar.gz"
        echo "  transfer surya mesasdk-x86_64-linux-23.7.3.tar.gz mesa-r23.05.1.zip"
        echo "  transfer laptop document.pdf"
        echo "  transfer pc report.tar.gz Desktop/"
        return 1
    end

    set -l target (string lower $argv[1])
    set -l remote_user_host ""
    set -l cur_host (hostname)

    switch $target
        case pc
            if test "$cur_host" = "void-pc"
                echo "Error: You are already on PC ($cur_host)."
                return 1
            end
            set remote_user_host "void@100.117.73.75"

        case laptop
            if test "$cur_host" = "void"
                echo "Error: You are already on Laptop ($cur_host)."
                return 1
            end
            set remote_user_host "void@100.70.236.70"

        case surya
            set remote_user_host "yashsharma@192.168.4.1"

        case aries
            set remote_user_host "shashi@172.18.1.5"

        case '*'
            echo "Error: Unknown target '$target'. Supported: pc, laptop, surya, aries"
            return 1
    end

    # Determine files vs optional destination directory
    set -l files
    set -l dest_path "~/"

    # If the last argument does not exist locally and there are > 2 args, treat as remote destination path
    if test (count $argv) -gt 2 -a ! -e "$argv[-1]"
        set dest_path "$argv[-1]"
        set files $argv[2..-2]
    else
        set files $argv[2..-1]
    end

    # Validate source files exist
    for f in $files
        if not test -e "$f"
            echo "Error: Cannot find local file or directory '$f'"
            return 1
        end
    end

    echo "Transferring to $target ($remote_user_host:$dest_path)..."
    rsync -ahP $files "$remote_user_host:$dest_path"
end
