#!/usr/bin/bash
set -euo pipefail

ROOT="${STEAM_SANDBOX_ROOT:?set STEAM_SANDBOX_ROOT to the sandbox folder}"
SANDBOX_HOME="$ROOT/home"
SHM="/dev/shm/steam-coop-play-$(id -u)"
DNS="169.254.1.1"
HOST_ADDRESS="${STEAM_SANDBOX_HOST_ADDRESS:-}"
CLEAN_ENV=(-u XDG_DATA_HOME -u XDG_CONFIG_HOME -u XDG_CACHE_HOME -u XDG_STATE_HOME HOME="$SANDBOX_HOME")

case "${1:-}" in
	steam)
		mkdir -p "$SANDBOX_HOME" "$ROOT/tmp" "$SHM"
		info="$ROOT/bwrap-info.json"
		rm -f "$info"
		printf 'nameserver %s\n' "$DNS" > "$ROOT/resolv.conf"
		env "${CLEAN_ENV[@]}" bwrap \
			--dev-bind / / \
			--unshare-ipc \
			--unshare-net \
			--info-fd 3 \
			--bind "$ROOT/tmp" /tmp \
			--bind /tmp/.X11-unix /tmp/.X11-unix \
			--bind "$SHM" /dev/shm \
			--ro-bind "$ROOT/resolv.conf" "$(realpath /etc/resolv.conf)" \
			-- bash -c 'until (( $(wc -l < /proc/net/route) > 1 )); do sleep 0.1; done; exec steam "$@"' steam "${@:2}" \
			3>"$info" &
		bwrap_pid=$!
		until grep -q '"child-pid"' "$info" 2>/dev/null; do
			kill -0 "$bwrap_pid" 2>/dev/null || exit 1
			sleep 0.1
		done
		child_pid="$(grep -o '"child-pid": *[0-9]*' "$info" | grep -o '[0-9]*$')"
		host_mapping=()
		if [[ -n "$HOST_ADDRESS" ]]; then
			host_mapping=(--map-host-loopback "$HOST_ADDRESS")
		fi
		pasta --config-net --quiet --no-netns-quit --no-map-gw -t none -u none -T none -U none \
			--dns-forward "$DNS" "${host_mapping[@]}" "$child_pid"
		wait "$bwrap_pid" || true
		pkill -f "^pasta .* $child_pid\$" || true
		;;
	run)
		steam_pid="$(cat "$SANDBOX_HOME/.steam/steam.pid")"
		exec env "${CLEAN_ENV[@]}" nsenter \
			--target "$steam_pid" --user --net --mount --ipc --preserve-credentials --wdns="$PWD" \
			-- "${@:2}"
		;;
	*)
		echo "usage: $0 steam [steam args] | run command [args]" >&2
		exit 2
		;;
esac
