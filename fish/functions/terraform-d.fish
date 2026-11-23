function terraform-d
    docker run --rm -it \
        --user (id -u):(id -g) -e HOME=/tmp \
        -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_REGION \
        -v (pwd):/workspace -w /workspace \
        hashicorp/terraform:1.17 $argv
end
funcsave terraform-d
