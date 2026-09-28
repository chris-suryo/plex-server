# 2. Start and connect the apps

URLs below use `mediabox.local` (at home). Over Tailscale, use `http://mediabox:<port>`. Apps reach each other **by name** (`sonarr`, `radarr`, `sabnzbd`, `gluetun`). Plex runs from the homelab repo on the host network, so it's always `192.168.77.20:32400`.

| App | URL | What it does |
|---|---|---|
| Plex *(homelab)* | `http://mediabox.local:32400/web` | Streams your library |
| Seerr | `http://mediabox.local:5055` | Search and request movies and shows; Plex Watchlist auto-requests |
| Sonarr | `http://mediabox.local:8989` | TV: finds, downloads, renames and imports episodes |
| Radarr | `http://mediabox.local:7878` | Movies: same job |
| Prowlarr | `http://mediabox.local:9696` | Manages indexers (search sources) for Sonarr/Radarr |
| Bazarr | `http://mediabox.local:6767` | Subtitles |
| Tautulli | `http://mediabox.local:8181` | Plex stats and history |
| SABnzbd | `http://mediabox.local:8085` | Usenet downloader (`usenet` profile) |
| qBittorrent | `http://mediabox.local:8080` | Torrent downloader behind the VPN (`torrent` profile) |

---

## Step 0: Pick a download source

Set `COMPOSE_PROFILES` in `.env` (`nano ~/plex-server/.env`). You can enable one or both and change it any time.

| | Usenet (`usenet`) | Torrents (`torrent`) |
|---|---|---|
| You need | A Usenet **provider** (the servers) plus one or two **indexers** (the search sites). See r/usenet's wiki for current options. | A **VPN with port forwarding**. ProtonVPN (paid plans) is the easiest with Gluetun. PIA and AirVPN also work. |
| Cost | ~$5–15/month total | ~$3–5/month for the VPN |
| Upkeep | Most hands-off; no VPN needed | More moving parts; speed depends on seeders |

Many people run Usenet as the main source with torrents as a fallback (`COMPOSE_PROFILES=usenet,torrent`).

> These tools are neutral automation software. You're responsible for what you download and where from. Copyright law applies.

### VPN settings (`torrent` profile only)

| Provider | `.env` settings |
|---|---|
| **ProtonVPN** (default) | In your Proton account, create a WireGuard config with **NAT-PMP (Port Forwarding)** enabled. Copy its `PrivateKey` into `WIREGUARD_PRIVATE_KEY`. Keep `VPN_PORT_FORWARDING=on` and `PORT_FORWARD_ONLY=on`. |
| **PIA** | `VPN_SERVICE_PROVIDER="private internet access"`, `VPN_TYPE=openvpn`, `OPENVPN_USER` / `OPENVPN_PASSWORD`, `VPN_PORT_FORWARDING=on`, `PORT_FORWARD_ONLY=on`. Gluetun then picks only servers that support port forwarding (PIA has none in the US). |
| **AirVPN** | `VPN_SERVICE_PROVIDER=airvpn`, `VPN_TYPE=wireguard`, plus `WIREGUARD_PRIVATE_KEY`, `WIREGUARD_PRESHARED_KEY` and `WIREGUARD_ADDRESSES` (IPv4 only) from AirVPN's config generator. Reserve a port in the client area and put it in `FIREWALL_VPN_INPUT_PORTS`. Set `VPN_PORT_FORWARDING=off` and `PORT_FORWARD_ONLY=` (blank). Then set that port as qBittorrent's listening port manually. |

Details for each provider: https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers

---

## Step 1: First start

```bash
cd ~/plex-server
nano .env                # COMPOSE_PROFILES, plus VPN details if using torrents
docker compose up -d
docker compose ps        # everything should be "running" (gluetun "healthy")
```

**Set a login on every app** the first time you open it. Sonarr, Radarr, Prowlarr and Bazarr ask for this on first visit: choose *Forms (Login Page)*.

---

## Step 2: Plex (homelab repo)

Plex is installed and configured by the homelab repo: [docs/08-mediabox-apps.md §4](https://github.com/chris-suryo/pi-hole-ad-blocker/blob/HEAD/docs/08-mediabox-apps.md). That covers libraries, Quick Sync, Remote Access and sharing with friends. Check it's running at `http://mediabox.local:32400/web`.

Inside the Plex container, the libraries are `/media/movies` and `/media/tv`, the same folders Sonarr/Radarr see as `/data/media/...`. That difference is expected. Plex notices new files on its own; there's nothing to configure here.

---

## Step 3a: SABnzbd (`usenet` profile)

1. Open `http://mediabox.local:8085`. The wizard asks for your Usenet provider: host, port `563`, ✅ SSL, username, password, connections. Test, then finish.
2. **Config → Folders**:
   - Temporary Download Folder: `/data/usenet/incomplete`
   - Completed Download Folder: `/data/usenet/complete`
3. **Config → Categories**: add `movies` (folder `movies`) and `tv` (folder `tv`).
4. **Config → General**: set a username and password, and copy the **API Key** for Step 4.

If you ever see *"Access denied – Hostname verification failed"*, add the hostname you used (e.g. `mediabox`) under **Config → Special → host_whitelist**.

## Step 3b: qBittorrent (`torrent` profile)

1. Check the VPN is up and isn't leaking your home IP:
   ```bash
   docker compose logs gluetun | grep -iE "public ip|port forwarded"
   docker exec gluetun wget -qO- https://ipinfo.io/ip    # must NOT be your home IP
   ```
2. Get the temporary admin password:
   ```bash
   docker compose logs qbittorrent | grep -i password
   ```
3. Open `http://mediabox.local:8080`, log in as `admin`, then go to **Tools → Options**:
   - **Web UI**: set a new password. ✅ *Bypass authentication for clients on localhost*. Gluetun needs this to push the forwarded port in.
   - **Downloads**: *Default Torrent Management Mode* = `Automatic`. *Default Save Path* = `/data/torrents`.
   - **Connection**: ❌ untick *Use UPnP / NAT-PMP port forwarding from my router*. The VPN handles the port.
   - **BitTorrent**: set seeding limits if you like (e.g. ratio 2.0, then pause).
4. Left sidebar → **Categories** → right-click → *Add category*:
   - `tv` → save path `/data/torrents/tv`
   - `movies` → save path `/data/torrents/movies`
5. After a minute, **Options → Connection → Port used for incoming connections** should show the VPN's forwarded port (not 6881).

---

## Step 4: Sonarr and Radarr

Do the same steps in both apps, using the values from this table:

| | Sonarr (`:8989`) | Radarr (`:7878`) |
|---|---|---|
| Root folder | `/data/media/tv` | `/data/media/movies` |
| Download client category | `tv` | `movies` |

1. **Settings → Media Management** (click *Show Advanced*):
   - ✅ *Rename Episodes* / *Rename Movies*
   - *Importing*: ✅ *Use Hardlinks instead of Copy* (on by default)
   - *Root Folders*: add the path from the table
2. **Settings → Download Clients → +**:
   - **SABnzbd**: Host `sabnzbd`, Port `8080`, API Key from Step 3a, Category from the table
   - **qBittorrent**: Host `gluetun`, Port `8080`, your qBittorrent username/password, Category from the table
   - Click *Test*, then *Save*
3. Don't add any *Remote Path Mappings*. The paths are identical in every container, so they aren't needed.
4. **Settings → General → API Key**: copy it into `.env` as `SONARR_API_KEY` / `RADARR_API_KEY`.

## Step 5: Apply the quality profiles (Recyclarr)

With both API keys in `.env`:

```bash
docker compose up -d                        # restarts Recyclarr/Unpackerr with the keys
docker compose run --rm recyclarr sync
```

You now have TRaSH Guides profiles: **WEB-1080p** in Sonarr and **HD Bluray + WEB** in Radarr. They prefer good-quality releases and block junk. Recyclarr re-syncs daily. The settings live in [`recyclarr/recyclarr.yml`](../recyclarr/recyclarr.yml).

## Step 6: Prowlarr (indexers)

1. Open `http://mediabox.local:9696`. Go to **Indexers → Add Indexer**, search for yours, and enter its API key or login.
2. **Settings → Apps → +**, add **Sonarr**:
   - Prowlarr Server: `http://prowlarr:9696`
   - Sonarr Server: `http://sonarr:8989`
   - API Key: Sonarr's key
3. Add **Radarr** the same way (`http://radarr:7878`).
4. Prowlarr now pushes your indexers into Sonarr and Radarr automatically. Check under **Settings → Indexers** in each.

If an indexer sits behind Cloudflare and fails, you may need **FlareSolverr** or its drop-in replacement **Byparr** (`ghcr.io/thephaseless/byparr`, port 8191). Add it to `compose.yaml` only if you need it.

---

## Step 7: Seerr (requests)

1. Open `http://mediabox.local:5055`, choose **Plex**, and sign in with your Plex account.
2. **Plex server**: pick yours from the list, or enter `192.168.77.20`, port `32400`. **Sync libraries** and enable Movies and TV. Don't use `localhost`: Plex runs on the host network.
3. **Services**:
   - **Radarr**:
     - Server settings: ✅ Default Server, Hostname `radarr`, Port `7878`, API Key.
     - Click *Test*, then pick Quality Profile `HD Bluray + WEB`, Root Folder `/data/media/movies`, Minimum Availability `Released`.
   - **Sonarr**:
     - Server settings: ✅ Default Server, Hostname `sonarr`, Port `8989`, API Key.
     - Click *Test*, then pick Quality Profile `WEB-1080p`, Root Folder `/data/media/tv`, ✅ Season Folders.
4. **Settings → Users**:
   - ✅ *Enable Plex Sign-In* / *New Plex Sign-In*. Anyone you share Plex with can log in with their Plex account.
   - **Default Permissions**: ✅ Request, ✅ **Auto-Approve**, ✅ **Auto-Request** (Movies and Series). This gives you the "request it and it just downloads" behavior you chose.
5. **Plex Watchlist auto-request**: each person signs in to Seerr **once**. After that, anything they add to their Watchlist in the normal Plex app (phone or TV) is requested automatically. Seerr checks on a schedule; see **Settings → Jobs & Cache → Plex Watchlist Sync**.

## Step 8: Bazarr and Tautulli (optional but useful)

- **Bazarr** (`:6767`):
  - **Settings → Sonarr** (host `sonarr`, port `8989`, API key) and **Radarr** (`radarr`, `7878`)
  - **Languages**: add a profile, e.g. English
  - **Providers**: add a couple, e.g. OpenSubtitles.com with a free account
  - Text subtitles (SRT) avoid the heavy "burn-in" transcodes that image subtitles cause.
- **Tautulli** (`:8181`): sign in with Plex and point it at `192.168.77.20:32400`.

---

## Step 9: End-to-end test

1. In Seerr, request ***Night of the Living Dead* (1968)**. It's in the public domain, so it's a legal test.
2. Watch it move through the pipeline:
   - Seerr: *Requested → Processing*
   - Radarr: **Activity → Queue**
   - Downloader: SABnzbd or qBittorrent
   - Radarr imports it
   - It appears in Plex
3. Torrents only: check that the import was a hardlink, not a copy:
   ```bash
   stat -c '%h %n' /srv/storage/data/media/movies/*/*.mkv    # "2" = hardlinked
   ```

## Troubleshooting

| Symptom | Fix |
|---|---|
| *Access denied* / import failed / Plex can't see new files | Permissions. Re-run `./scripts/bootstrap.sh`; it resets ownership. Check `PUID`/`PGID` in `.env` match `id -u` / `id -g`. |
| Sonarr/Radarr can't reach qBittorrent | Use host `gluetun`, not `qbittorrent`. Check `docker compose ps` shows gluetun *healthy*. |
| qBittorrent has no connectivity after Gluetun restarted | `docker compose restart qbittorrent` (it shares Gluetun's network, so it needs to reconnect). |
| Downloads are **copied** and use double the space | `torrents/` and `media/` must be on one filesystem/ZFS dataset (re-run `bootstrap.sh`; it tests this). Don't add extra volume mounts. |
| Seerr: *Unable to connect to Plex* | Use `192.168.77.20`, not `localhost`/`plex`. Check Plex is up (homelab). |
| Nothing ever downloads | Check Prowlarr has working indexers and has synced them to both apps. In Sonarr/Radarr, check **Activity → Queue**, **System → Status** and the logs. |

Useful commands:

```bash
docker compose ps                    # status
docker compose logs -f sonarr        # follow one app's logs (Ctrl+C to stop)
docker compose restart radarr        # restart one app
docker compose up -d                 # apply .env / compose.yaml changes
```

Next: [03-friends-access.md](03-friends-access.md)
