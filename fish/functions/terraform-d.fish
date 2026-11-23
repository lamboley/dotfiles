function terraform-d
    set -l envfile
    test -f .env; and set envfile --env-file .env
    docker run --rm -it \
        --user (id -u):(id -g) -e HOME=/tmp \
        $envfile \
        -v (pwd):/workspace -w /workspace \
        hashicorp/terraform:1.17 $argv
end
funcsave terraform-d
