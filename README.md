# Steam Co-op Play

A Godot editor plugin for testing Steam multiplayer on one Linux machine. One click runs your main scene twice:

- once on your normal Steam account, like the editor's Play button
- once on a second Steam account, through a second Steam client running in a sandbox

Both instances are real Steam users, so lobbies, invites, P2P networking and friends work as they would on two separate PCs. You don't need to export a build or use a second computer.

## Requirements

- Linux
- Godot 4.4 or newer, as the official binary. The Flatpak build of Godot can't create the sandbox. Tested on 4.7.2.
- Native Steam, with the `steam` command on your `PATH`. Flatpak Steam won't work.
- `bwrap` (bubblewrap), `pasta` (from passt), `nsenter` (from util-linux) and `bash`. Most distributions already include them. Podman and Flatpak pull in `bwrap` and `pasta`.
- A second Steam account that:
  - can launch your game's App ID (for example, added to your Steamworks partner group, or given a key)
  - is friends with your main account, if your game uses friends-only lobbies
- About 2.5 GB of disk space for the second Steam client.

## Installation

1. Copy `addons/steam_coop_play` into your project's `addons/` folder.
2. Enable **Steam Co-op Play** in **Project → Project Settings → Plugins**.
3. Optional: choose where the second Steam client is stored, in **Editor → Editor Settings → Plugins → Steam Coop Play → Sandbox Root**. The default is `~/.local/share/godot/steam_coop_play`. This is a per-machine setting and isn't saved in the project.

### As a git submodule

You can use a submodule instead of copying the folder in step 1. The repository keeps the plugin in `addons/steam_coop_play/`, so add it in a hidden folder that Godot skips, then link the plugin into `addons/`:

```sh
git submodule add https://github.com/Polynezeas/steam-coop-play.git .submodules/steam-coop-play
ln -s ../.submodules/steam-coop-play/addons/steam_coop_play addons/steam_coop_play
```

Commit both the submodule and the symlink. Clone the project with `git clone --recurse-submodules`, or run `git submodule update --init` after cloning. Otherwise the link points at an empty folder.

To update the plugin later, run `git submodule update --remote .submodules/steam-coop-play` and commit the new submodule pointer.

## Usage

Press the Steam button in the editor toolbar.

**The first time**, the plugin starts the second Steam client. It downloads its own copy of Steam into the sandbox folder, then shows a login window. Log in with your second account and tick "Remember me". The button shows *Waiting for Steam…* until the login finishes, then starts both instances.

**After that**, the second Steam client stays open between runs, so later presses start both instances straight away. If the second client was closed, it logs back in with its saved token.

While the game is running, the button stays pressed. Press it again, or use Godot's Stop button, to stop both instances. The second instance connects to the editor's debugger, so its output and errors appear as a separate session in the Debugger dock.

If **Debug → Customize Run Instances → Enable Multiple Instances** is on, the plugin turns it off just for its own launch and then turns it back on. That way you get exactly one instance per Steam account.

## How it works

A game finds the running Steam client through:

- files in the home folder
- shared memory in `/dev/shm`
- SysV semaphores
- a fixed localhost port

All of these belong to your Linux user, not to a Steam account, so a second Steam client would normally collide with the first. `steam_sandbox.sh` gives the second client its own copy of each:

- **Home folder:** the sandbox folder's `home/`
- **`/tmp`:** the sandbox folder's `tmp/`
- **`/dev/shm`:** `/dev/shm/steam-coop-play-<uid>`
- **IPC namespace:** a separate one, for its own semaphores
- **Network namespace:** a separate one, so it has its own `127.0.0.1`. `pasta` gives that namespace internet access, with port forwarding to and from the host turned off.

The second game instance joins the same namespaces with `nsenter`. As a result, `SteamAPI_Init` in that instance connects to the second Steam client. Your game code doesn't need any changes.

You can also run the script outside the editor:

```sh
export STEAM_SANDBOX_ROOT=~/.local/share/godot/steam_coop_play
bash addons/steam_coop_play/steam_sandbox.sh steam                     # start the second Steam client
bash addons/steam_coop_play/steam_sandbox.sh run <command> [args...]   # run a command inside its sandbox
```

## Troubleshooting

**The button stays on "Waiting for Steam…"**
Look at the second Steam window. It may be waiting for you to log in or to pick the account. The plugin detects the login by reading the second client's `connection_log.txt`, so a change to Steam's log format could also cause this.

**Both instances use the same account**
The second instance isn't reaching the sandboxed client. Check that the second Steam client is running and logged in before you press the button.

**`bwrap` or `nsenter` fails with a permission error on Ubuntu 24.04 or newer**
Ubuntu restricts unprivileged user namespaces through AppArmor. Allow them for `bwrap` with an AppArmor profile, or set `kernel.apparmor_restrict_unprivileged_userns=0`.

**Removing everything**
- Delete the plugin folder.
- Delete the sandbox folder (Sandbox Root).
- Delete `/dev/shm/steam-coop-play-<uid>`, which is also cleared on reboot.

## License

MIT, see [LICENSE](LICENSE).

The Steam icon is from [Simple Icons](https://simpleicons.org) (CC0). Steam and the Steam logo are trademarks of Valve Corporation. This plugin is not affiliated with or endorsed by Valve.
