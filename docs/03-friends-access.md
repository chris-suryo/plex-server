# 3. Friends and family: requesting, and your own remote admin

Three kinds of access, each handled by a different piece:

| Who / what | How | Where it's set up |
|---|---|---|
| Friends and family **watching** | Plex Remote Access (TCP `32400` forwarded to `mediabox`) + library sharing + Plex Pass | **homelab repo**, `docs/08-mediabox-apps.md` §4 |
| Friends and family **requesting** | Plex Watchlist, plus a one-time Seerr sign-in | **This page** |
| **You** managing Sonarr, Radarr, etc. from anywhere | Tailscale | **homelab repo**, `docs/05-tailscale.md` (the PC joins in Phase 6) |

> 🚫 **Never** port-forward Seerr, Sonarr, Radarr, Prowlarr, Bazarr, SABnzbd, qBittorrent or Tautulli. Exposed *arr and downloader UIs get found and abused. Plex's `32400` is the only forwarded port.

## 1. Requesting via the Plex Watchlist (no extra app)

With Seerr's Watchlist auto-request ([02-configure-apps.md](02-configure-apps.md), Step 7), friends add a title to their **Watchlist** in the normal Plex app and it downloads automatically. The "Auto-Approve" default you chose means nobody has to approve it.

The catch: each friend has to **sign in to Seerr once** so it can read their watchlist. So Seerr must be reachable for them at least that once. Pick A or B below.

## A. Cloudflare Tunnel for Seerr (recommended for friends)

This publishes **only Seerr** at a web address like `https://requests.yourdomain.com`, with no open ports on the router. Friends log in with their Plex account. You need a domain on Cloudflare (~$10/yr). The tunnel is free, and the same domain can later serve homelab's "HTTPS names" plan (Phase 8).

1. Cloudflare dashboard → **Zero Trust → Networks → Tunnels → Create a tunnel** (type *Cloudflared*). Name it (e.g. `mediabox-seerr`) and copy the **token**.
2. In `.env`: set `CLOUDFLARE_TUNNEL_TOKEN=<token>`. Add `public` to `COMPOSE_PROFILES` (e.g. `COMPOSE_PROFILES=usenet,public`).
3. `docker compose up -d`
4. In the tunnel's **Public Hostname** tab, add:

   | Field | Value |
   |---|---|
   | Subdomain | `requests` |
   | Domain | your domain |
   | Service type | **HTTP** |
   | URL | `seerr:5055` |

5. Send friends the link. They sign in once with Plex, and after that they can use the Watchlist or the Seerr site (add it to their home screen as an app).

> Route **only Seerr** through the tunnel. Streaming Plex video through Cloudflare violates its terms, and the *arr apps must stay private.

## B. Tailscale sharing (household / a few people)

For people comfortable installing an app. In the Tailscale admin console, share the `mediabox` machine with them (**Machines → mediabox → ⋯ → Share**). They then open `http://mediabox:5055`.

## 2. Your admin access from anywhere

Once homelab Phase 6 has put `mediabox` on your tailnet, everything here works away from home too, as long as Tailscale is on:

- Sonarr: `http://mediabox:8989`
- Radarr: `http://mediabox:7878`
- SABnzbd: `http://mediabox:8085`
- qBittorrent: `http://mediabox:8080`
- and so on for the other apps

For SABnzbd via a hostname, add `mediabox` and `mediabox.local` under **Config → Special → host_whitelist**.

Phone apps for managing things:

- **Android**: nzb360
- **iOS**: Ruddarr (Sonarr/Radarr)
- **Both**: Seerr in the browser (Share → *Add to Home Screen*)

Use the `mediabox` addresses above in all of them.

## 3. Security checklist

- [ ] Only TCP `32400` (Plex) is forwarded on the router; nothing from this repo
- [ ] Every app has a login set; qBittorrent's default password was changed
- [ ] `docker exec gluetun wget -qO- https://ipinfo.io/ip` shows the VPN's IP, not yours (torrent profile)
- [ ] `.env` is never committed (it's git-ignored) and is included in homelab's backups
- [ ] Updates run every week or two: `./scripts/update.sh`
