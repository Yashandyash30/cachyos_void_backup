function ssharies --description 'SSH into ARIES server (instant clean login with Jupyter tunnel)'
    if test (count $argv) -eq 0
        ssh -t aries "exec bash --noprofile --rcfile ~/.bashrc"
    else
        ssh aries $argv
    end
end
