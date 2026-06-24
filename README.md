<a href="https://github.com/lamboley/dotfiles/actions/workflows/sast.yml"><img src="https://github.com/lamboley/dotfiles/actions/workflows/sast.yml/badge.svg" alt="sast" /></a>

# Dotfiles

Ce projet contient mes dotfiles.
Le fichier [install.sh](https://raw.githubusercontent.com/lamboley/dotfiles/master/install/install.sh) installe, **en user-local (`~/.local`), sans sudo** :

- Le shell `Fish` (plugins via `fisher` : tide, z, fzf.fish).
- Les outils `fzf`, `eza`, `zoxide`, `keychain`, `lazygit`.
- L'éditeur `Helix` (et un `Neovim` minimal).
- Le multiplexeur `Zellij`.
- `Golang`, le programme Go `sshm` (+ `ghq`) et une config ssh hardened.
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

Outils : `zellij`, `lazygit`, `fzf`, `eza`, `zoxide`, `keychain`, `go`, `nvim`, `sshm`, `ghq`, `hx`.
Les shells (`fish`) sont exclus pour éviter tout lockout.

> `uninstall.sh` reste dédié à la purge des doublons **système** (apt/dnf/pkg),
> distinct de `install.sh uninstall` qui retire la version **user-local**.
