function update-packages --description "Met à jour les paquets système"
    if set -q PREFIX; and string match -q '*com.termux*' -- $PREFIX
        pkg update -y; and pkg upgrade -y; and apt clean -y; and apt autoremove -y
    else if command -q apt
        sudo apt update -y; and sudo apt upgrade -y; and sudo apt clean -y; and sudo apt autoremove -y
    end
end
