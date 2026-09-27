# 5. Remote access: friends, family and you

There are three different kinds of access, each handled a different way:

| Who / what | How | Open ports |
|---|---|---|
| Friends and family **watching** | Plex Remote Access | TCP `32400` only |
| Friends and family **requesting** | Plex Watchlist, plus a one-time Seerr sign-in | None (Cloudflare Tunnel) |
| **You** managing Sonarr, Radarr, etc. | Tailscale (private VPN app) | None |

> 🚫 **Never** port-forward Sonarr, Radarr, Prowlarr, Bazarr, SABnzbd, qBittorrent or Tautulli. Exposed *arr and downloader UIs get found and abused.

## 1. Check that your internet connection can host

1. Log in to your router (often `http://192.168.1.1` or `http://192.168.0.1`; the login is usually on a sticker). Find the **WAN / Internet IP**.
2. Compare it with https://ifconfig.me opened from any home device.
   - **Same** → good, you have a public IP.
   - **Different**, or the router shows `100.64.x.x`–`100.127.x.x`, `10.x.x.x` or `192.168.x.x` → your ISP uses **CGNAT** (it shares one public IP between customers). Port forwarding won't work, and Plex falls back to a relay capped at ~1–2 Mbps. Ask your ISP for a public IPv4 address; it's often free or a few dollars a month.
3. Run a speed test and note the **upload** speed. That's what remote viewers share. A 1080p remote stream needs ~8 Mbps, so e.g. 40 Mbps upload ≈ 4–5 simultaneous friends.

## 2. Plex Remote Access (watching)

1. Make sure the server has a DHCP reservation (fixed IP; see [02-install-ubuntu.md](02-install-ubuntu.md)).
2. In the router, **port forward TCP 32400 → SERVER_IP:32400**.
3. Plex → **Settings → Remote Access**:
   - Enable it
   - ✅ *Manually specify public port*: `32400`
   - It should say **"Fully accessible outside your network"**
4. Same page: set **Internet upload speed** to your measured upload. Set **Limit remote stream bitrate** to e.g. `8 Mbps (1080p)` so one friend can't hog the connection.

### Plex Pass and remote viewers

Since 2025, streaming your videos **outside your home** needs one of:

- **Your** Plex Pass (as server owner). Then *everyone you share with streams free*. $69.99/yr, or $249.99 for 5 years.
- Or each remote viewer buys their own **Remote Watch Pass** ($2.99/mo) or Plex Pass.

People on your home network never need anything. Plex Pass also unlocks hardware transcoding, which matters once several friends stream at once.

## 3. Share your library

Plex web → **Settings → Manage Library Access** (or plex.tv → *Users & Sharing*) → **Grant Library Access** → enter the friend's email and pick libraries.

The friend then:

1. Creates a free Plex account
2. Accepts the invite
3. Installs the Plex app on their TV or phone, and your server shows up

## 4. Friends requesting titles

### The easy way: Plex Watchlist (no extra app)

With Seerr's Watchlist auto-request ([04-configure-apps.md](04-configure-apps.md), Step 7), friends just add a title to their **Watchlist** in the Plex app and it downloads automatically.

The catch: each friend has to **sign in to Seerr once** so it can read their watchlist. So Seerr must be reachable for them at least that once. The two options below cover that.

### Option A: Cloudflare Tunnel for Seerr (recommended for friends)

This publishes only Seerr at a web address like `https://requests.yourdomain.com`, with no open ports. Friends log in with their Plex account. You need a domain on Cloudflare (~$10/yr); the tunnel itself is free.

1. Cloudflare dashboard → **Zero Trust → Networks → Tunnels → Create a tunnel** (type *Cloudflared*). Name it and copy the **token**.
2. In `.env`: set `CLOUDFLARE_TUNNEL_TOKEN=<token>` and add `public` to `COMPOSE_PROFILES` (e.g. `COMPOSE_PROFILES=usenet,public`).
3. `docker compose up -d`
4. In the tunnel's **Public Hostname** tab, add:

   | Field | Value |
   |---|---|
   | Subdomain | `requests` |
   | Domain | your domain |
   | Service type | **HTTP** |
   | URL | `seerr:5055` |

5. Send friends the link. They sign in once with Plex, and from then on they can use the Watchlist or the Seerr site (add it to their home screen as an app).

> Route **only Seerr** through the tunnel. Streaming Plex video through Cloudflare violates its terms, and the *arr apps must stay private.

### Option B: Tailscale sharing (household / a few people)

Good for family members who are comfortable installing an app. See section 5. Share the server with them from the Tailscale admin console (**Machines → ⋯ → Share**), and they open `http://mediaserver:5055`.

## 5. Your own admin access: Tailscale

Tailscale creates a private encrypted network between your devices. The free plan covers 6 users with unlimited devices.

```bash
# on the server
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up          # open the printed link and log in
```

Install Tailscale on your phone and laptop with the same account. Then, from anywhere, open `http://mediaserver:8989` (Sonarr), `http://mediaserver:7878` (Radarr) and so on. Use the server's hostname, or its `100.x.x.x` Tailscale IP.

For SABnzbd via hostname, add `mediaserver` under **Config → Special → host_whitelist**.

Phone apps for managing things:

- **Android**: nzb360
- **iOS**: Ruddarr (Sonarr/Radarr)
- **Both**: Seerr in the browser (Share → *Add to Home Screen*)

(LunaSea was discontinued in 2025.)

## 6. Security checklist

- [ ] Only TCP `32400` is forwarded on the router (nothing else, unless you know why)
- [ ] Every app has a login set; qBittorrent's default password was changed
- [ ] **2FA enabled on your Plex account** (plex.tv → Account → Security)
- [ ] `.env` is not committed anywhere (it's git-ignored)
- [ ] Updates run regularly: `./scripts/update.sh` (see the README)
- [ ] Backups scheduled: `scripts/backup.sh` (see the README)
