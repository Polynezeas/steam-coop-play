<p align="center">
  <img src="assetlib/icon.png" alt="Steam Co-op Play logo" width="128">
</p>

# Steam Co-op Play

A Godot editor plugin for testing Steam multiplayer on one Linux machine. One click runs your main scene twice: once on your normal Steam account, and once on a second account through a sandboxed second Steam client. Both are real Steam users, so lobbies, invites and P2P work like on two PCs.

## Requirements

- Linux, with `bwrap`, `pasta`, `nsenter` and `bash` (most distros include them)
- Godot 4.4+, official binary (not Flatpak)
- Native Steam (not Flatpak), with `steam` on your `PATH`
- A second Steam account that can launch your App ID and is friends with your main account
- About 2.5 GB of disk space for the second Steam client

## Installation

1. Copy `addons/steam_coop_play` into your project's `addons/` folder.
2. Enable **Steam Co-op Play** in **Project Settings → Plugins**.
3. Optional: set where the second client is stored in **Editor Settings → Plugins → Steam Coop Play → Sandbox Root** (default `~/.local/share/godot/steam_coop_play`).

**As a git submodule:** the plugin lives in `addons/steam_coop_play/` inside this repo, so add the submodule in a hidden folder and link it:

```sh
git submodule add https://github.com/Polynezeas/steam-coop-play.git .submodules/steam-coop-play
ln -s ../.submodules/steam-coop-play/addons/steam_coop_play addons/steam_coop_play
```

Clone with `--recurse-submodules`, and update with `git submodule update --remote`.

## Usage

Press the Steam button in the toolbar. The first time, the second Steam client installs itself and asks you to log in; tick "Remember me". After that it stays open, and each press starts both instances right away. Press the button again, or Godot's Stop, to stop both. The second instance appears as its own session in the Debugger dock.

## How it works

A game finds Steam through files in the home folder, `/dev/shm`, SysV semaphores and a fixed localhost port, all shared per Linux user. `steam_sandbox.sh` runs the second client with its own home, `/tmp`, `/dev/shm`, IPC namespace and network namespace (given internet by `pasta`). The second game instance joins those namespaces with `nsenter`, so it connects to the second client. No game code changes are needed.

## Troubleshooting

- **Stuck on "Waiting for Steam…":** check the second Steam window; it may want a login or an account pick.
- **Permission errors on Ubuntu 24.04+:** AppArmor blocks unprivileged user namespaces. Add a profile for `bwrap`, or set `kernel.apparmor_restrict_unprivileged_userns=0`.
- **Uninstalling:** delete the plugin folder and the Sandbox Root folder.

## License

MIT, see [LICENSE](LICENSE). Steam icon from [Simple Icons](https://simpleicons.org) (CC0). Steam is a trademark of Valve Corporation; this plugin is not affiliated with Valve.
