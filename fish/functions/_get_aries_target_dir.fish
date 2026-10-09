function _get_aries_target_dir
    set -l raw_path $argv[1]
    if test -z "$raw_path"
        set raw_path $PWD
    end

    # Strip file:// prefix if present
    set raw_path (string replace -r '^file://' '' $raw_path)

    # If it is an SFTP url (e.g. sftp://shashi@172.18.1.5/path or sftp://aries/path)
    set -l sftp_rem (string replace -r '^sftp://[^/]+' '' $raw_path)
    if test "$sftp_rem" != "$raw_path"
        echo $sftp_rem
        return
    end

    # If it is a local mount path
    if string match -q "/home/void/Remote/ARIES*" $raw_path
        set -l target_dir (string replace "/home/void/Remote/ARIES" "/home/shashi" $raw_path)
        echo $target_dir
        return
    else if string match -q "/mnt/ARIES*" $raw_path
        set -l target_dir (string replace "/mnt/ARIES" "/home/shashi" $raw_path)
        echo $target_dir
        return
    end

    # If already a remote path on ARIES
    if string match -q "/home/shashi*" $raw_path
        echo $raw_path
        return
    end

    # If it is a local home path, translate /home/void -> /home/shashi
    if string match -q "/home/void*" $raw_path
        set -l target_dir (string replace "/home/void" "/home/shashi" $raw_path)
        echo $target_dir
        return
    end

    echo "/home/shashi"
end
