<a href="https://github.com/lamboley/dotfiles/actions/workflows/sast.yml"><img src="https://github.com/lamboley/dotfiles/actions/workflows/sast.yml/badge.svg" alt="sast" /></a>

# Dotfiles

Ce projet contient mes dotfiles.
Le fichier [install.sh](https://raw.githubusercontent.com/lamboley/dotfiles/master/install/install.sh) installe, **en user-local (`~/.local`), sans sudo** :

- Le shell `Fish` (plugins via `fisher` : tide, z).
- Les outils `zoxide`, `keychain`, `lazygit`.
- L'éditeur `Helix`.
- Le multiplexeur `Zellij`.
- `Golang`, le programme Go `sshm` et une config ssh.
- La font `FiraCode Nerd Font` et le terminal `Alacritty` (GUI).

## Installation

> ˋbashˋ est necessaire.

| Method    | Command                                                                                           |
| :-------- | :------------------------------------------------------------------------------------------------ |
| **curl**  | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/install/install.sh)"` |

## Par outil

Installer ou retirer **un seul** outil en user-local, sans relancer toute l'install :

| Action          | Commande                               |
| :-------------- | :------------------------------------- |
| Installer       | `install/install.sh install <outil>`   |
| Retirer (local) | `install/install.sh uninstall <outil>` |

Outils : `zellij`, `lazygit`, `zoxide`, `keychain`, `go`, `sshm`, `hx`.
Les shells (`fish`) sont exclus pour éviter tout lockout.
