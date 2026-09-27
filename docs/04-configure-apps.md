# 4. Start and connect the apps

Replace `SERVER_IP` below with the server's LAN IP. Apps reach each other **by name** (`sonarr`, `radarr`, `sabnzbd`, `gluetun`), except for Plex, which uses host networking and is reached at `SERVER_IP:32400`.

| App | URL | What it does |
|---|---|---|
| Plex | `http://SERVER_IP:32400/web` | Streams your library |
| Seerr | `http://SERVER_IP:5055` | Search and request movies and shows; Plex Watchlist auto-requests |
| Sonarr | `http://SERVER_IP:8989` | TV: finds, downloads, renames and imports episodes |
| Radarr | `http://SERVER_IP:7878` | Movies: same job |
| Prowlarr | `http://SERVER_IP:9696` | Manages indexers (search sources) for Sonarr/Radarr |
| Bazarr | `http://SERVER_IP:6767` | Subtitles |
| Tautulli | `http://SERVER_IP:8181` | Plex stats and history |
| SABnzbd | `http://SERVER_IP:8085` | Usenet downloader (`usenet` profile) |
| qBittorrent | `http://SERVER_IP:8080` | Torrent downloader behind the VPN (`torrent` profile) |

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
nano .env                # set PLEX_CLAIM from https://www.plex.tv/claim (valid 4 minutes!)
docker compose up -d
docker compose ps        # everything should be "running" (gluetun "healthy")
```

Missed the 4-minute claim window? No problem: open `http://SERVER_IP:32400/web` from a PC on your home network and sign in there.

**Set a login on every app** the first time you open it. Sonarr, Radarr, Prowlarr and Bazarr ask for this on first visit: choose *Forms (Login Page)*.

---

## Step 2: Plex

1. Open `http://SERVER_IP:32400/web` and sign in. Give the server a name.
2. **Add libraries**:
   - *Movies* → folder `/data/media/movies`
   - *TV Shows* → folder `/data/media/tv`
3. **Settings → Library**: ✅ *Scan my library automatically*, ✅ *Run a partial scan when changes are detected*.
4. **Settings → Transcoder** (needs Plex Pass): ✅ *Use hardware acceleration when available*, ✅ *Use hardware-accelerated video encoding*, ✅ *Enable HDR tone mapping*.
5. Remote access and sharing with friends: [05-remote-access.md](05-remote-access.md).

---

## Step 3a: SABnzbd (`usenet` profile)

1. Open `http://SERVER_IP:8085`. The wizard asks for your Usenet provider: host, port `563`, ✅ SSL, username, password, connections. Test, then finish.
2. **Config → Folders**:
   - Temporary Download Folder: `/data/usenet/incomplete`
   - Completed Download Folder: `/data/usenet/complete`
3. **Config → Categories**: add `movies` (folder `movies`) and `tv` (folder `tv`).
4. **Config → General**: set a username and password, and copy the **API Key** for Step 4.

If you ever see *"Access denied – Hostname verification failed"*, add the hostname you used (e.g. `mediaserver`) under **Config → Special → host_whitelist**.

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
3. Open `http://SERVER_IP:8080`, log in as `admin`, then go to **Tools → Options**:
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

1. Open `http://SERVER_IP:9696`. Go to **Indexers → Add Indexer**, search for yours, and enter its API key or login.
2. **Settings → Apps → +**, add **Sonarr**:
   - Prowlarr Server: `http://prowlarr:9696`
   - Sonarr Server: `http://sonarr:8989`
   - API Key: Sonarr's key
3. Add **Radarr** the same way (`http://radarr:7878`).
4. Prowlarr now pushes your indexers into Sonarr and Radarr automatically. Check under **Settings → Indexers** in each.

If an indexer sits behind Cloudflare and fails, you may need **FlareSolverr** or its drop-in replacement **Byparr** (`ghcr.io/thephaseless/byparr`, port 8191). Add it to `compose.yaml` only if you need it.

---

## Step 7: Seerr (requests)

1. Open `http://SERVER_IP:5055`, choose **Plex**, and sign in with your Plex account.
2. **Plex server**: pick yours from the list, or enter `SERVER_IP`, port `32400`. **Sync libraries** and enable Movies and TV. Don't use `localhost`: Plex runs on the host network.
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
- **Tautulli** (`:8181`): sign in with Plex and point it at `SERVER_IP:32400`.

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
   stat -c '%h %n' /data/media/movies/*/*.mkv    # "2" = hardlinked
   ```

## Step 10: Check hardware transcoding (Plex Pass)

Play something in the Plex app and set the quality to something low, e.g. *720p 2 Mbps*. Plex **Dashboard** should show **Transcode (hw)**. Live view of the iGPU at work:

```bash
sudo intel_gpu_top
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Plex won't start: *error gathering device information … /dev/dri* | The iGPU is disabled. Fix the BIOS setting ([01-hardware.md](01-hardware.md)) and check `ls /dev/dri`. |
| *Access denied* / import failed / Plex can't see files | Permissions. Re-run `./scripts/bootstrap.sh`; it resets ownership. Check `PUID`/`PGID` in `.env` match `id -u` / `id -g`. |
| Sonarr/Radarr can't reach qBittorrent | Use host `gluetun`, not `qbittorrent`. Check `docker compose ps` shows gluetun *healthy*. |
| qBittorrent has no connectivity after Gluetun restarted | `docker compose restart qbittorrent` (it shares Gluetun's network, so it needs to reconnect). |
| Downloads are **copied** and use double the space | Don't add extra volume mounts. All apps must see the same `/data` paths. |
| Seerr: *Unable to connect to Plex* | Use `SERVER_IP`, not `localhost`/`plex`. |
| Nothing ever downloads | Check Prowlarr has working indexers and has synced them to both apps. In Sonarr/Radarr, check **Activity → Queue**, **System → Status** and the logs. |

Useful commands:

```bash
docker compose ps                    # status
docker compose logs -f sonarr        # follow one app's logs (Ctrl+C to stop)
docker compose restart radarr        # restart one app
docker compose up -d                 # apply .env / compose.yaml changes
```

Next: [05-remote-access.md](05-remote-access.md)
