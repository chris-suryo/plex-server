# 1. Prerequisites and setup

This repo is the **media automation layer**: requests, Sonarr/Radarr and the downloaders. It runs on the media PC (`mediabox`) **after** the homelab repo has built that machine: [github.com/chris-suryo/pi-hole-ad-blocker](https://github.com/chris-suryo/pi-hole-ad-blocker).

## Who owns what

| homelab repo (`pi-hole-ad-blocker`) | this repo (`plex-server`) |
|---|---|
| Network, router, Pi-hole, Tailscale, Uptime Kuma, Portainer | Seerr (requests + Plex Watchlist auto-request) |
| Media PC hardware, BIOS, Ubuntu, data drives, Docker | Sonarr, Radarr, Prowlarr, Recyclarr, Bazarr |
| **Plex** (incl. Remote Access and sharing with friends), Jellyfin | SABnzbd and/or qBittorrent + Gluetun VPN, Unpackerr |
| Immich, Samba/Time Machine | Tautulli (Plex stats) |
| Backups of `/srv/appdata`, UPS, alerts | Cloudflare Tunnel for Seerr (friends' sign-in) |

## Shared conventions

Both repos rely on these, so change them in both places or not at all.

| What | Value |
|---|---|
| Media PC | `mediabox`, `192.168.77.20` (LAN: `mediabox.local`; Tailscale: `mediabox`) |
| User | Your normal user, `PUID`/`PGID` = `1000` |
| App settings | `/srv/appdata/<app>` on the boot SSD (backed up by homelab) |
| Media + downloads | **`/srv/storage/data`**, with `media/` inside it. homelab's Plex/Jellyfin read `/srv/storage/data/media` (`MEDIA_DIR`). |
| Ports on `mediabox` | homelab: Plex 32400, Jellyfin 8096, Immich 2283. This repo: 5055, 8989, 7878, 9696, 6767, 8181, 8085, 8080. |

### Why `/srv/storage/data` must be one filesystem

Sonarr/Radarr import finished downloads by **hardlinking** (torrents) or **instantly moving** (Usenet) them into `media/`. That only works when downloads and media sit on the **same filesystem**. With the planned ZFS mirror, that means one dataset for all of `data/`. If `torrents/` and `media/` end up on different datasets or drives, every import turns into a slow full copy that uses double the space. `bootstrap.sh` tests this for you.

## Checklist before starting

From the homelab repo:

- [ ] **Phase 1** (router) and **Phase 6** (media PC: hardware, Ubuntu, fixed IP `192.168.77.20`, data drive, Docker, Tailscale) are done
- [ ] **Phase 7 §4: Plex is running** at `http://mediabox.local:32400/web`, with libraries at `/media/movies` and `/media/tv`
- [ ] `stacks/.env` there has `MEDIA_DIR=/srv/storage/data/media`

## Install this stack

```bash
cd ~
git clone https://github.com/chris-suryo/plex-server.git   # private repo? use: gh repo clone chris-suryo/plex-server
cd plex-server
./scripts/bootstrap.sh
```

`bootstrap.sh` does four things:

1. Creates `.env`
2. Builds the folder tree
3. Checks that hardlinks work
4. Validates the compose file

The folder tree it creates:

```
/srv/storage/data
├── torrents/{movies,tv}
├── usenet/{incomplete,complete/{movies,tv}}
└── media/{movies,tv}          <- Plex/Jellyfin (homelab) read this
```

Next: [02-configure-apps.md](02-configure-apps.md)
