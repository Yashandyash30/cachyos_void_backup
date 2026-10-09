function checkmonitors
    echo "Querying physical monitor power states..."
    ssh void@100.117.73.75 "ddcutil -d 1 getvcp d6 || true; ddcutil -d 2 getvcp d6 || true"
end
