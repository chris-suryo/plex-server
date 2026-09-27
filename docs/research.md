# Home Media Server on an Old PC: Plex + *arr Stack. Research Report (as of 27 Sep 2026)

Goal: a phone/TV app where you search for a movie or show, tap "request", and it downloads and shows up in Plex on its own, like the friend's setup.

How to read this: the recommended default stack comes first. Then the biggest changes since 2025, then one section per topic, and finally a list of things I could not verify. Source URLs are inline. Version numbers and dates marked "(GH)" come straight from each project's GitHub release feed, checked on 27 Sep 2026.

> Research method note: plex.tv, trash-guides.info, wiki.servarr.com, unraid.net, jellyfin.org, yams.media and most news sites were blocked for direct fetching from this environment. For those I used search-result snippets and secondary coverage, and pulled GitHub sources directly (TRaSH Guides, Seerr docs, Gluetun wiki, release feeds). Where that matters, it is flagged.

> Legal note: the *arr tools are neutral automation software. Downloading copyrighted material you don't have rights to is illegal in many countries, and on public torrent trackers your IP is visible to everyone in the swarm. Treat the torrent/Usenet discussion below as technical, not as legal advice.

---

## 0. Recommended default stack (beginner, reliability-first)

| Layer | Pick | Why / notes |
|---|---|---|
| **Host OS** | **Ubuntu Server 24.04/26.04 LTS or Debian 13, plus Docker Engine and Docker Compose** (not Docker Desktop) | Most guides, TRaSH and YAMS target it. Free, stable, one compose file. Pick **Unraid** instead only if you have many mixed-size drives and want a web UI and are willing to pay (Lifetime $249). |
| **Media server** | **Plex Media Server** (official `plexinc/pms-docker` or `lscr.io/linuxserver/plex`) | Best client apps and simplest for non-technical family and friends. Budget for **Plex Pass** if anyone streams from outside your home or you want GPU/iGPU transcoding. Jellyfin can run next to it for free as a fallback. |
| **Request app** ("search and request") | **Seerr** (`ghcr.io/seerr-team/seerr`, port 5055) | Overseerr and Jellyseerr merged into Seerr in Feb 2026. **Turn on Plex Watchlist Auto-Request**: users add a title to their Watchlist in the normal Plex app on TV or phone and it gets requested automatically. That matches the "friend's setup" experience. |
| **TV** | **Sonarr v4** | Current stable is v4.0.20 (GH, 16 Sep 2026). |
| **Movies** | **Radarr v6** | Current stable is 6.4.4 (GH, 14 Sep 2026). |
| **Indexers** | **Prowlarr** | Syncs indexers into Sonarr and Radarr. 2.6.5 (GH, 16 Sep 2026). |
| **Quality profiles** | **TRaSH Guides profiles, synced with Recyclarr** (or Configarr/Clonarr) | Stops Sonarr/Radarr from grabbing junk. Recyclarr 8.7.2 (GH, 3 Sep 2026). |
| **Subtitles** (optional) | **Bazarr** | 1.6.2 (GH, 26 Sep 2026). |
| **Download: Usenet** (preferred if you'll pay about $5–15/mo) | **SABnzbd** | Easiest for beginners. **Update to 5.1.3+**: 5.1.2/5.1.3 (Aug/Sep 2026) fixed RCE and path-traversal bugs. |
| **Download: torrents** | **qBittorrent inside Gluetun** (`network_mode: "service:gluetun"`) with a **port-forwarding VPN** (ProtonVPN paid plan, PIA, or AirVPN) | Kill-switch by design. Gluetun can push the forwarded port into qBittorrent automatically. |
| **Extraction** | **Unpackerr** | Only needed for torrents that arrive as .rar files. 0.16.1 (GH, 31 Aug 2026). |
| **Cloudflare-protected indexers** | Only if you need one: **FlareSolverr**, or **Byparr** as a drop-in on the same port 8191 | Many users report FlareSolverr failing on newer Cloudflare challenges. |
| **Stats** | **Tautulli** | 2.18.1 (GH, 27 Aug 2026). |
| **Dashboard** (optional) | **Homepage** (YAML) or **Homarr** (GUI) | Both active (Homepage 2.4.0, Homarr 1.77.2, Sep 2026). |
| **Updates** | **Diun or What's Up Docker for notifications, then `docker compose pull && docker compose up -d` by hand**. If you want auto-updates, use the maintained fork **`nickfedor/watchtower`**. | The original `containrrr/watchtower` was **archived 17 Dec 2025**. |
| **Remote access** | Plex's built-in Remote Access for streaming. **Tailscale** for you to reach the admin UIs. Seerr behind a reverse proxy (Caddy or NPM) only if friends need it. | **Never port-forward** Sonarr, Radarr, Prowlarr, qBittorrent or SABnzbd. |
| **Folders** | One `/data` tree (`/data/{torrents,usenet,media}`) mounted into every container as `/data`. `PUID=1000`, `PGID=1000`, `UMASK=002`. | Makes hardlinks and instant moves work, as in TRaSH Guides. |
| **Hardware** | Any **Intel 8th gen or newer CPU with an iGPU** (not an "F" model), 8–16 GB RAM, **SSD for OS, appdata and Plex metadata**, HDDs for media | 12th gen or newer is the sweet spot for AV1 decode and HDR tone mapping. |
| **Phone** | Plex app (Watchlist), Seerr as a home-screen web app (PWA), **nzb360** (Android) or **Ruddarr** (iOS) for admin | LunaSea was discontinued in April 2025. |

---

## 0.1 Most important changes since 2025

1. **Plex monetisation.**
   - Remote streaming of your own video now needs **Plex Pass on the server owner's account**, or **Plex Pass or Remote Watch Pass on the viewer's account**. The policy started 29 Apr 2025.
   - Enforcement has been rolling out by device: Roku from Nov 2025, smart TVs and consoles from 23 Mar 2026, then Fire TV, Apple TV, Android TV and third-party API clients "in 2026".
   - **Lifetime Plex Pass went from $249.99 to $749.99 on 1 Jul 2026.** A new **5-year Plex Pass costs $249.99**.
   - **Remote Watch Pass went from $1.99 to $2.99/mo ($19.99 to $29.99/yr) on 1 Jun 2026.**
   - Hardware transcoding is still Plex Pass-only.
2. **Overseerr and Jellyseerr became Seerr** (merger announced 10 Feb 2026). The Overseerr repo was archived 15 Feb 2026 and LinuxServer deprecated its `overseerr` image (16 Feb 2026). Seerr v3.4.1 is current (GH, 30 Jul 2026).
3. **Readarr was retired** on 27 Jun 2025 because its metadata stopped working. LazyLibrarian is the usual replacement.
4. **Watchtower** (`containrrr`) was **archived** on 17 Dec 2025. The maintained fork is `nickfedor/watchtower`, v1.22.3 (GH, 22 Sep 2026).
5. **LunaSea** (mobile *arr app) was discontinued in April 2025.
6. **Huntarr** (a popular add-on) collapsed in Feb 2026 after it was found exposing all connected *arr API keys without authentication. Its repo was pulled. If you ever ran it, rotate your API keys.
7. **Jellyfin 12.0** (7–8 Sep 2026) and **12.1** (15 Sep 2026) came out; the version numbering jumped from 10.11 to 12. **Radarr moved to v6.** Lidarr is now v3.1.x.
8. **Tailscale's free Personal plan** now allows **6 users with unlimited devices** (pricing v4, Apr 2026).
9. **Plex security:** there was an account-database breach in Sep 2025 (password reset required; turn on 2FA), and more PMS security patches in mid/late 2026. Keep PMS updated.

---

## 1. Media server: Plex vs Jellyfin vs Emby (2026)

### 1.1 Plex: what's free vs paid today

| Feature | Free Plex account | Remote Watch Pass (viewer-side) | Plex Pass (owner- or viewer-side) |
|---|---|---|---|
| Run Plex Media Server, organise libraries, metadata | Yes | – | Yes |
| Stream your media **inside your home network** (all apps, including mobile) | **Yes.** The old one-time mobile unlock fee was removed in 2025. | – | Yes |
| Stream your personal **video remotely** (outside home) | **No** (since 29 Apr 2025, enforced per platform) | **Yes**, for that viewer only, from any server | **Yes.** If the **server owner** has Plex Pass, *everyone* the owner shares with can stream remotely at no cost to them. |
| **Hardware-accelerated transcoding** (Quick Sync/NVENC), HW HDR tone mapping, **HEVC encoding** (out of preview Jan 2025) | No (CPU/software transcoding only) | No (it's a viewer pass; it doesn't unlock server features) | **Yes** (server owner) |
| Downloads/offline sync, skip intro/credits, and other "premium" features | No | No | Yes |

**Prices (USD):**
- Plex Pass: **$6.99/mo** or **$69.99/yr**. These rose from $4.99/$39.99 on 29 Apr 2025.
- **5-year Plex Pass: $249.99** (new July 2026).
- **Lifetime Plex Pass: $749.99** since 1 Jul 2026 (was $249.99; before Apr 2025 it was $119.99).
- **Remote Watch Pass: $2.99/mo or $29.99/yr** since 1 Jun 2026 (introductory price was $1.99/$19.99). There is no lifetime option.

Sources:
- https://www.plex.tv/blog/new-lifetime-plex-pass-pricing/ (via search snippet; plex.tv was blocked for direct fetch)
- https://9to5mac.com/2026/05/19/plex-increasing-lifetime-plex-pass-cost-to-whopping-750/
- https://thedesk.net/2026/07/plex-raises-price-of-lifetime-plex-pass-introduces-five-year-plan-at-250/
- https://www.thefpsreview.com/2026/05/20/plex-triples-its-lifetime-pass-price-to-749-99-starting-july-1-2026/
- https://www.howtogeek.com/plex-remote-watch-pass-gets-a-price-increase/
- https://www.androidauthority.com/plex-remote-watch-pass-price-increase-3663060/
- https://www.xda-developers.com/plex-slaps-price-increase-on-remote-watch-pass/
- https://support.plex.tv/articles/requirements-for-remote-playback-of-personal-media/
- https://www.privacyguides.org/news/2025/11/26/plex-begins-enforcing-new-restrictions-on-remote-streaming-this-week/
- https://9to5mac.com/2025/11/27/plex-paywall-for-remote-streaming-now-being-enforced/
- https://forums.plex.tv/t/changes-coming-to-remote-streaming-on-smart-tvs/937015
- https://www.howtogeek.com/plex-fire-tv-redesign-remote-streaming-limits/
- https://support.plex.tv/articles/115002178853-using-hardware-accelerated-streaming/
- https://techcrunch.com/2025/03/19/streamer-plex-raises-subscription-price-for-the-first-time-in-a-decade
- https://thedesk.net/2025/03/plex-dropping-mobile-activation-fees/
- https://www.howtogeek.com/plex-hevc-encoding-and-public-profiles/

**What this means for this user:**
- If everyone watches **at home only** and the CPU can handle any transcoding in software, **free Plex works**.
- For **remote streaming**, for sharing with family and friends in other homes, or for iGPU hardware transcoding, you need Plex Pass. The **$69.99/yr** or the **$249.99 5-year** plan is the sensible buy now that lifetime costs $750.
- The popular 2025 trick of treating Tailscale IPs (100.64.0.0/10) as "LAN" to dodge the remote paywall has had **"numerous reports in 2026" of no longer working**, according to the guide's own author. Don't plan around it. Sources: https://github.com/fullmetalbrackets/blog/blob/main/src/content/blog/plex-remote-access-tailscale.md and https://forums.plex.tv/t/can-no-longer-connect-to-plex-via-1st-party-apps-using-tailscale/936328

### 1.2 Jellyfin
- Fully free and open source. **Hardware transcoding is free.** No account with a third party is needed.
- Current versions: **12.1 (15 Sep 2026)** and **12.0 (8 Sep 2026)** (GH). 10.11 was the last "10.x" branch. Source: https://github.com/jellyfin/jellyfin/releases
- Trade-offs:
  - Remote access is do-it-yourself: reverse proxy, VPN or Tailscale.
  - Client polish varies by TV platform.
  - Nothing matches Plex's "invite a friend by email" flow.
- Community consensus in 2025–2026: Jellyfin is the default for cost and privacy, and Plex wins on polish and ease for non-technical viewers. Source: https://jellywatch.app/blog/jellyfin-vs-plex-2026-comparison (a Jellyfin-adjacent blog, so somewhat biased).

### 1.3 Emby
- Closed source, somewhere between Plex and Jellyfin. **Emby Premiere costs $4.99/mo, $54/yr or $119 lifetime** (it was briefly $99 in Nov 2025).
- Emby is rarely recommended for new builds in 2026.
- Sources: https://emby.media/support/articles/Premiere-Membership-Options.html and https://www.neowin.net/news/emby-premiere-lifetime-discounted-to-99-likely-the-last-time-price-will-be-so-low/

### 1.4 Recommendation
- Go with **Plex**, since the user explicitly wants the friend's Plex-style experience.
- You can run **Jellyfin alongside it** on the same `/data/media` for free, with no conflicts. That's a free safety net if Plex pricing keeps climbing.
- Seerr supports both servers, so the request flow works the same either way.

---

## 2. Automation components: what they do and their status (Sept 2026)

| Component | What it does | Status (Sept 2026) | Recommend? |
|---|---|---|---|
| **Sonarr** | Monitors TV shows, grabs episodes, renames and imports them | Active. **v4.0.20.3014 (16 Sep 2026)**. No v5 release yet. https://github.com/Sonarr/Sonarr/releases | Yes |
| **Radarr** | Same job for movies | Active. **v6.4.4.10685 (14 Sep 2026)**. v6 added PostgreSQL connection-string options, rqbit client support and more. https://github.com/Radarr/Radarr/releases | Yes |
| **Prowlarr** | One place to manage indexers, synced to all the *arrs | Active. **2.6.5 (16 Sep 2026)** | Yes |
| **Bazarr** | Fetches subtitles | Active. **v1.6.2 (26 Sep 2026)** | Optional |
| **Lidarr** | Music | Active. **v3.1.6 (13 Sep 2026)**. However, its **metadata server has had repeated reliability problems** (MusicBrainz schema change in mid-2025, plus 2026 reports of adding artists failing). https://community.metabrainz.org/t/for-those-using-lidarr-and-musicbrainz-metadata/768255, https://www.joekarlsson.com/blog/self-hosted-music-still-sucks-in-2026/ | Only if you want music. Expect friction. |
| **Readarr** | Books | **Retired on 27 Jun 2025**: metadata is unusable and development stopped. https://wiki.servarr.com/readarr/status, https://github.com/geekau/mediastack/issues/66 | **No.** Use LazyLibrarian (or Audiobookshelf for audiobooks). |
| **Seerr** (formerly Overseerr/Jellyseerr) | Request front-end: search TMDB, request, send to Sonarr/Radarr, notify when available. Has **Plex Watchlist Auto-Request**. | Active. **v3.4.1 (30 Jul 2026)**. Image is `ghcr.io/seerr-team/seerr:latest`, port 5055. Supports Plex, Jellyfin and Emby. Migration is automatic on first start. The container **runs as the non-root `node` user (UID 1000)** and needs `init: true`, config at `/app/config` owned by `1000:1000`, and **no `user:` directive**. Sources: https://docs.seerr.dev/blog/seerr-release/, https://github.com/seerr-team/seerr, `docs/migration-guide.mdx` and `docs/using-seerr/plex/watchlist-auto-request.md` in the repo | **Yes. This is the core of the "request it on my phone" experience.** |
| **Overseerr / Jellyseerr** | Predecessors of Seerr | **Overseerr archived 15 Feb 2026.** The Jellyseerr repo became Seerr. LinuxServer deprecated its Overseerr image (https://info.linuxserver.io/issues/2026-02-16-overseerr/). | No. Use Seerr. |
| **Recyclarr** | CLI/YAML tool that syncs TRaSH custom formats and quality profiles into Sonarr/Radarr | Active. **v8.7.2 (3 Sep 2026)** | Yes |
| **Configarr / Clonarr / Notifiarr** | Other TRaSH-approved "Guide Sync" tools. Clonarr has a web UI; Notifiarr is a paid patron feature. | Listed as officially supported on TRaSH's Guide-Sync page (`docs/Guide-Sync/index.md` in the TRaSH repo). **Profilarr** (GUI) is popular but *not* on TRaSH's official list. | Alternatives to Recyclarr |
| **FlareSolverr** | Proxy that solves Cloudflare challenges for some indexers | Repo is still active: **v3.5.2 (12 Sep 2026)**, v3.5.0 (May 2026). The README still warns that captcha solvers don't work, and many 2026 reports say it fails on newer Cloudflare Turnstile/Managed challenges. https://github.com/FlareSolverr/FlareSolverr | Only if an indexer needs it |
| **Byparr** | Drop-in FlareSolverr replacement (same API, port 8191), Camoufox-based | Active. **v3.0.4 (18 Aug 2026)**. Image `ghcr.io/thephaseless/byparr`. https://github.com/ThePhaseless/Byparr | Try this first if FlareSolverr fails |
| **Unpackerr** | Extracts rar'd torrent downloads so the *arrs can import them | Active. **v0.16.1 (31 Aug 2026)** | Yes if you use torrents. Usenet clients extract on their own. |
| **Tautulli** | Plex stats, history and notifications | Active. **v2.18.1 (27 Aug 2026)** | Nice to have |
| **Homepage / Homarr** | Dashboards | Both active: Homepage **v2.4.0 (17 Sep 2026)**, Homarr **v1.77.2 (18 Sep 2026)** | Optional |
| **Watchtower** (`containrrr/watchtower`) | Auto-updates containers | **Archived 17 Dec 2025, no longer maintained.** https://github.com/containrrr/watchtower, https://github.com/containrrr/watchtower/discussions/2135 | **No** |
| **`nickfedor/watchtower`** | Maintained continuation, API-compatible | Active. **v1.22.3 (22 Sep 2026)**. https://github.com/nicholas-fedor/watchtower | OK if you want auto-updates |
| **Diun / What's Up Docker (WUD)** | Notify-only update checkers | Active. Common recommendations. https://linuxhandbook.com/blog/watchtower-like-docker-tools/, https://www.xda-developers.com/watchtower-docker-updater-replacement-diun/ | **Recommended for beginners:** notify, then update by hand |
| **Huntarr** | "Hunts" for missing or upgradeable media | **Avoid.** In Feb 2026 it was found returning every connected app's API keys and passwords unauthenticated; the repo and subreddit were pulled. https://piunikaweb.com/2026/02/24/huntarr-security-vulnerability-arr-api-keys-exposed/, https://lemmy.world/post/43496203 | No |
| **Decluttarr / Cleanuparr** | Remove stalled or failed downloads from queues | Community-recommended after Huntarr (https://corelab.tech/sonarr-radarr-profilarr-native-hunting-protocol/) | Optional, later |
| **Maintainerr** | Rule-based cleanup of watched or old media in Plex | Popular | Optional, later |

**Image sources.**
- **LinuxServer.io** (`lscr.io/linuxserver/*`) and **hotio** (`ghcr.io/hotio/*`) are both well maintained.
- TRaSH's own example compose uses hotio images.
- Hotio's images are lean and update quickly. LinuxServer covers more apps. **Ignore any "suggested" separate `/movies` and `/downloads` volume paths in image docs**; use TRaSH's `/data` layout instead.
- Sources: https://hotio.dev/faq/ and the TRaSH repo `includes/docker/docker-compose.yml`.

---

## 3. Download clients, Usenet vs torrents, and VPN

### 3.1 Torrent clients
- **qBittorrent** is the community default in 2026. It has the best *arr integration (categories, content-layout options), handles thousands of torrents, and is actively developed (5.2.x series in 2026).
- **Deluge** 2.x is fine but develops slowly and struggles past about 500 torrents.
- **Transmission** 4.x is simple and light but has fewer knobs.
- Pitfall: since qBittorrent 4.6.1 the WebUI's **default password is random and printed in the container log** on first start.
- Sources: https://selfhosting.sh/compare/deluge-vs-qbittorrent/, https://www.pistack.xyz/posts/self-hosted-torrent-clients-guide/, https://github.com/qbittorrent/qBittorrent/releases

### 3.2 Usenet clients
- **SABnzbd** is recommended for beginners: polished UI, guided setup, very active.
  - **5.1.2 (25 Aug 2026)** fixed a *critical remote code execution* bug and a path-traversal bug. **5.1.3 (8 Sep 2026)** fixed more security issues. 5.2.0 Beta1 is out.
  - **Run 5.1.3 or newer and never expose it to the internet.** (GH: https://github.com/sabnzbd/sabnzbd/releases)
- **NZBGet** is maintained again by the community fork at **nzbget.com / `nzbgetcom/nzbget`**: v26.0 (Feb 2026) through **v26.3 (27 Aug 2026)**, with v27 in testing. It's lighter (C++) and a fine choice. The old "nzbget-ng" fork is effectively superseded by nzbgetcom.
- Sources: https://github.com/nzbgetcom/nzbget/releases and https://diymediaserver.com/post/choosing-the-right-usenet-file-manager/

### 3.3 Torrents vs Usenet

| | Torrents (public/private trackers) | Usenet |
|---|---|---|
| Cost | Client is free. A **VPN (about $2.50–$5/mo)** is effectively required for public trackers. | Provider (roughly $2–10/mo on deals, e.g. NewsDemon "unlimited" promos around $24/yr) **plus** one or two indexers (about $10–25/yr each). Budget roughly $5–15/mo. |
| Speed | Depends on seeders. Old or niche content can stall. | Usually maxes out your line, and completion is predictable. |
| Privacy | Your IP is visible to the whole swarm unless you use a VPN. DMCA letters are common without one. | You connect to the provider over SSL. No peers see you, and no VPN is needed. |
| Reliability | Good for popular content. Private trackers are excellent but need invites and ratio. | Very good for recent mainstream content. Older content can hit takedowns, so use multiple indexers or a second "block" account on another backbone. |
| Setup effort | Low, but VPN plus port forwarding adds complexity | Moderate (provider plus indexers), then very hands-off |

- Community view in 2026: **Usenet wins for "set and forget" automation.** Many people run both, with Usenet primary and torrents as a fallback.
- Sources: https://diymediaserver.com/post/torrent-vs-usenet/, https://www.rapidseedbox.com/blog/usenet-vs-torrenting, https://slickdeals.net/f/17758206-newsdemon-unlimited-usenet-for-24-year

### 3.4 VPN pattern: Gluetun plus qBittorrent
- **Standard pattern:**
  - Run **`qmcgaw/gluetun`** (v3.41.3, 30 Jul 2026, GH) and start qBittorrent with `network_mode: "service:gluetun"`.
  - qBittorrent's WebUI port gets published **on the gluetun service**, not on qBittorrent.
  - If the VPN drops, qBittorrent has no network at all, which is a built-in kill switch.
  - Only the torrent client goes through the VPN. Plex and the *arrs stay on the normal network, so Plex remote access and metadata keep working.
  - Don't install a system-wide VPN on the host; that breaks Plex remote access.
- **Port forwarding** matters for good torrent speeds and connectability.
  - Gluetun's **native** port-forwarding support covers **Private Internet Access, ProtonVPN, Perfect Privacy and PrivateVPN**. Set `VPN_PORT_FORWARDING=on`.
  - Gluetun can update qBittorrent's listen port automatically via `VPN_PORT_FORWARDING_UP_COMMAND`, which POSTs `listen_port={{PORT}}` to qBittorrent's API at `127.0.0.1:8080`. This requires qBittorrent's WebUI on 8080 with "Bypass authentication for clients on localhost" enabled.
  - For other providers (static forwarded ports, e.g. **AirVPN**), set `FIREWALL_VPN_INPUT_PORTS` manually.
  - Source: https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/vpn-port-forwarding.md
- **Providers that still support port forwarding in 2026:**
  - **ProtonVPN**: paid plans only, P2P servers only, via NAT-PMP. The port is random and gets renewed, so the Gluetun automation is ideal. https://protonvpn.com/support/port-forwarding
  - **PIA**: non-US servers only, dynamic port. https://natchecker.com/blog/pia-port-forwarding
  - **AirVPN**: static, reservable ports.
  - Also reported: TorGuard and Windscribe (Windscribe not re-verified for 2026).
  - **Mullvad removed port forwarding in July 2023** (https://mullvad.net/en/blog/removing-the-support-for-forwarded-ports) and dropped OpenVPN in Jan 2026. It's fine for privacy but not for seeding performance.
  - Tip from the community: ProtonVPN WireGuard keys can expire or desync, and then Gluetun fails silently. Watch Gluetun's health check.
  - https://www.secureguides.com/vpn-with-port-forwarding-the-ultimate-guide/
- **Alternative:** hotio's qBittorrent image has built-in WireGuard. That's simpler, but Gluetun is more flexible and the most widely documented.

---

## 4. Host OS for an old PC

| Option | Cost | Pros | Cons | Beginner verdict |
|---|---|---|---|---|
| **Ubuntu Server LTS (24.04 or 26.04) / Debian 13 + Docker Engine + Compose** | Free | The most documented path: TRaSH, YAMS and most guides. Easy iGPU passthrough (`/dev/dri`). Rock solid. | CLI only (add Portainer, Dockge or Komodo for a UI). Disk pooling and parity are DIY. | **Top pick for reliability.** Guides call Debian/Ubuntu + Docker "the right fit if you just want apps running." https://selfhostlife.com/best-home-server-os/, https://bigguyonstuff.com/proxmox-vs-truenas-vs-unraid-2026/ |
| **Unraid 7.x** (7.3.x stable, 7.4 beta as of Sep 2026) | **Starter $49** (up to 6 devices), **Unleashed $109** (unlimited devices); both include 1 year of updates, then an optional **$36/yr**. **Lifetime $249.** | Friendliest GUI. Mixed-size drives with real-time parity. App store ("Community Apps"). Has TRaSH-specific docs. Boots from USB. | Paid. Array write speed is limited by parity. Pointless on a single-drive box. | Great if you have 3+ mismatched HDDs and want clicks, not CLI. https://unraid.net/blog/new-pricing, https://unraid.net/blog/summer-sale-2026, https://docs.unraid.net/unraid-os/release-notes/7.3.2/ |
| **TrueNAS Community Edition (formerly SCALE) 25.10 "Goldeye"** | Free | ZFS with snapshots and self-healing. Since 24.10 apps are **plain Docker** (k3s was dropped). There's a "Custom App" YAML/compose editor. **RAIDZ expansion** (add one disk to a RAIDZ vdev) has been available since 24.10/OpenZFS 2.3. | Wants matched disks and plenty of RAM. The app layer is opinionated (UID 568 for iX apps). Hardlinks don't cross ZFS datasets, so keep `/data` as one dataset. | Good if you want ZFS. A bit more to learn. TrueNAS 26 is in beta; 25.10.x is the 2026 stable. https://www.truenas.com/blog/truenas-goldeye-25-10/, https://www.truenas.com/blog/truenas-plans-for-2026/ |
| **Proxmox VE 9.x** (9.2, May 2026; Debian 13 base) | Free (nag screen) | VMs and LXCs, snapshots, room to grow a homelab | Adds a layer: iGPU passthrough into an LXC or VM, bind mounts, UID mapping. The #1 source of beginner permission and hardlink headaches. | Only if you want to learn virtualisation. https://pve.proxmox.com/wiki/Roadmap |
| **OpenMediaVault 8 "Synchrony"** (Debian 13; OMV 7 EOL June 2026) | Free | NAS web UI on Debian. The `openmediavault-compose` plugin manages compose stacks. The mergerfs and SnapRAID plugins are the easy way to pool mixed drives. | Plugin ecosystem (omv-extras). A smaller community than Unraid. | Solid free "NAS GUI + Docker" middle ground. https://wiki.omv-extras.org/doku.php?id=omv8%3Aomv8_plugins%3Adocker_compose |
| **Windows + Docker Desktop** | Free | Familiar | **Hardlinks don't work** from WSL2 containers onto Windows NTFS drives (DrvFs doesn't support `link()`). There are file-watch and permission problems, Windows Update reboots, and Defender scanning. | **Not recommended.** If you must use Windows, install the apps **natively** (Plex, Sonarr and Radarr all have Windows installers) and keep downloads and media on the **same NTFS volume** so hardlinks work. https://github.com/logabell/dewarr/issues/15, https://docs.docker.com/desktop/features/wsl/best-practices/ |

**Beginner recommendation:**
- **Ubuntu Server LTS or Debian 13 with Docker Compose** if you're comfortable in a terminal for an afternoon. Everything in TRaSH, YAMS and Servarr maps onto it 1:1.
- **Unraid** if you want a GUI and have lots of mixed drives.
- **OMV 8** for a free GUI option.
- Avoid Proxmox and Windows Docker Desktop for a first build.

---

## 5. Hardware

### 5.1 CPU, RAM and SSD
- **The *arr apps are light.** Sonarr, Radarr, Prowlarr, Bazarr and Seerr each take roughly 150–500 MB of RAM. A whole stack plus Plex runs comfortably in **8 GB**. **16 GB** leaves headroom (qBittorrent with many torrents, Jellyfin alongside, a tmpfs transcode directory).
- **Minimum:** any 64-bit quad-core from about 2015 or later. **Direct play costs almost no CPU.** Transcoding is what's expensive.
- **Plex's CPU-only guidance:**
  - About 2,000 PassMark per 1080p (10 Mbps) transcode.
  - About **12,000 PassMark for one 4K SDR transcode** and about **17,000 for one 4K HDR (HEVC 10-bit) to 1080p transcode**.
  - Without a supported GPU or iGPU, one 4K HDR transcode will crush most old desktops.
  - https://support.plex.tv/articles/201774043-what-kind-of-cpu-do-i-need-for-my-server/
- **Put the OS, Docker appdata and especially the Plex metadata database on an SSD.** The Plex DB and thumbnails can reach tens of GB, and running them from an HDD makes the UI sluggish. HDDs are for `/data` only.

### 5.2 Intel Quick Sync: which generation matters (Plex needs Plex Pass for HW transcoding)

| Intel gen (iGPU) | HEVC 8-bit | HEVC 10-bit (most 4K/HDR) | VP9 | AV1 decode | AV1 encode | Notes |
|---|---|---|---|---|---|---|
| 6th Skylake (HD 5xx) | dec/enc | partial or hybrid | partial | – | – | Avoid for HDR/4K sources |
| **7th Kaby Lake to 10th Comet Lake** (HD/UHD 6xx) | yes | **dec/enc** | dec | – | – | **Practical minimum for 4K HEVC.** An 8th–10th gen i3/i5 desktop is a great free starting point. |
| **11th Tiger Lake / Rocket Lake** (Xe / UHD 750) | yes | yes | yes | **yes** | – | First with AV1 decode. Plex **HW tone mapping on Windows needs Tiger Lake or newer**; Linux supports older chips (reports say Kaby/Coffee Lake or newer). |
| **12th–14th Alder/Raptor Lake** (UHD 730/770), N100/N150/N305 | yes | yes | yes | **yes** | – | **Sweet spot.** Reportedly about 4–6 simultaneous 4K HDR to 1080p tone-mapped transcodes. UHD 770 (i5-12500/13500 and up) is the favourite. |
| Core Ultra (Meteor/Lunar/Arrow Lake), Intel Arc dGPU | yes | yes | yes | yes | **yes** | AV1 encode. Plex doesn't need it today. A cheap Arc A310/A380 is a popular add-in card for older PCs. |

- **"F" SKUs (e.g. i5-12400F) have no iGPU.** Check the BIOS: some boards disable the iGPU when a dGPU is installed.
- Sources:
  - https://www.serverrigs.com/guides/intel-quicksync-by-generation/
  - https://corelab.tech/best-plex-server-hardware/
  - https://minilabhq.com/posts/n100-mini-pc-for-plex-transcoding/
  - https://support.plex.tv/articles/hdr-to-sdr-tone-mapping/
  - https://blog.lon.tv/2025/01/04/plex-hdr-hardware-tone-mapping-comes-to-windows-sponsored-post/
  - https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/intel/

### 5.3 NVIDIA and AMD
- **NVIDIA NVENC** is fully supported by Plex on Linux and Windows.
  - In Docker you need the NVIDIA driver plus `nvidia-container-toolkit`.
  - Consumer GeForce cards are limited to **8 concurrent NVENC sessions** per system (raised from 5 in 2024; the GTX 1630 is limited to 3). The `keylase/nvidia-patch` removes the limit.
  - A Turing or newer card (GTX 1650 Super, T400/T600/T1000, RTX) is the typical pick for an old desktop without a usable iGPU.
  - Sources: https://docs.nvidia.com/video-technologies/video-codec-sdk/13.0/nvenc-application-note/index.html, https://videocardz.com/newz/nvdia-geforce-gpus-now-support-up-to-8-concurrent-nvenc-encoding-sessions, https://github.com/keylase/nvidia-patch
- **AMD GPUs and APUs:** Plex support is **"as is, your mileage may vary."** On Linux Docker it only works with community VAAPI hacks, and Plex's HEVC encoding explicitly doesn't support AMD. **Avoid AMD for Plex transcoding.** Jellyfin handles AMD better.
  - Sources: https://support.plex.tv/articles/115002178853-using-hardware-accelerated-streaming/, https://github.com/jefflessard/plex-vaapi-amdgpu-mod

### 5.4 4K realities and stream counts
- **Best practice: don't transcode 4K at all.**
  - Direct-play 4K on capable TVs and streamers at home.
  - Keep a **1080p copy** for remote or weak clients. TRaSH suggests a separate Radarr and Sonarr instance or a separate profile for 4K.
- **Image-based subtitles (PGS/VobSub) force a burn-in transcode** on most clients. Plex skips HW tone mapping during burn-in, which is very slow for 4K HDR. Prefer SRT subtitles (Bazarr can fetch them).
  - Sources: https://forums.plex.tv/t/pgs-subtitles-and-hw-transcode-issues/882439, https://gist.github.com/bogsen/37cbad60f6c10cdaddf3b07a56e06147
- **Rough capacity:**
  - Direct play is limited only by disk and network speed.
  - An 8th–10th gen iGPU handles about 10–20 simultaneous 1080p to 720p/1080p transcodes, or 2–3 4K HEVC to 1080p (tone mapping support varies by OS).
  - A 12th gen or newer UHD 770 handles about 4–6 4K HDR tone-mapped transcodes.
  - Your **upload bandwidth** is usually the real limit for remote streams.
  - These are community estimates, not benchmarks. See https://quicksync.ktz.me/

### 5.5 Storage
- **Sizing (rough estimates):**
  - 1080p WEB-DL movie: about 4–10 GB. 1080p TV episode: about 1–3 GB.
  - 4K WEB-DL movie: about 15–25 GB. **4K remux: 40–80 GB.**
  - A few hundred 1080p movies plus a dozen series fits in about 4–8 TB.
  - Buy the largest **CMR** drives you can afford. Recertified enterprise drives are popular. **Avoid SMR** drives for parity and ZFS.
- **Pooling options:**
  - **Single disk (ext4/xfs):** simplest. Fine to start, but there's no redundancy, so keep backups of appdata at least.
  - **mergerfs + SnapRAID:** free, mixes drive sizes, each disk readable on its own, parity updated on a schedule (not real time). A great fit for media, which is mostly write-once.
    - Hardlink caveat: mergerfs can only hardlink within the **same underlying branch**. Use a path-preserving create policy (e.g. `epmfs`/`epff`) so downloads and media land on the same disk.
    - https://perfectmediaserver.com/02-tech-stack/snapraid/, https://diymediaserver.com/post/2026/mergerfs-media-servers-2026/
  - **ZFS (TrueNAS/Proxmox/Ubuntu):** real-time redundancy, checksums and snapshots. Wants matched drives. RAIDZ expansion is now possible one disk at a time. Keep `/data` as **one dataset**, because hardlinks can't cross datasets.
    - https://www.theregister.com/2025/01/23/openzfs_23_raid_expansion/
  - **Unraid array:** real-time parity with mixed sizes and easy growth. Paid. TRaSH has Unraid-specific share and cache ("mover") guidance.
- **Media is replaceable; config isn't.** Back up `/docker/appdata` (or equivalent), especially the *arr databases and Plex's DB. RAID or parity is not a backup.

---

## 6. Folder structure and permissions (TRaSH Guides)

**The key rule:** every app sees the **same single mount (`/data`)** at the **same path**, with downloads and media on the **same filesystem**. Then Sonarr and Radarr can **hardlink** (seed a torrent and have it in your library while using the disk space once) or do **atomic moves** (instant renames for Usenet) instead of slow copies. Mapping `/tv`, `/movies` and `/downloads` as separate volumes breaks this. That's the #1 beginner mistake.

TRaSH's recommended tree (verbatim from `includes/file-and-folder-structure/docker-tree-full.md` in the TRaSH repo):

```
data
├── torrents
│   ├── books
│   ├── movies
│   ├── music
│   └── tv
├── usenet
│   ├── incomplete
│   └── complete
│       ├── books
│       ├── movies
│       ├── music
│       └── tv
└── media
    ├── books
    ├── movies
    ├── music
    └── tv
```

**Volume mappings** (from TRaSH's example compose, which uses hotio images, `PUID=1000`, `PGID=1000`, and config under `/docker/appdata/<app>`):

| Container | Mount |
|---|---|
| Sonarr, Radarr (and Lidarr) | `/data:/data` (full tree) |
| qBittorrent | `/data/torrents:/data/torrents` |
| SABnzbd / NZBGet | `/data/usenet:/data/usenet` |
| Plex, Jellyfin, Bazarr | `/data/media:/data/media` |
| Every app | `/docker/appdata/<app>:/config` on the **SSD** |

- In qBittorrent, set **categories** (`tv`, `movies`) whose save paths are `/data/torrents/tv` and so on.
- In SABnzbd, set the complete folder to `/data/usenet/complete` and use categories.
- **Don't** set "Remote Path Mappings" in the *arrs. With identical paths you don't need them.

**Permissions:**
- Run every container with the same `PUID`/`PGID` (usually your user, 1000:1000) and **`UMASK=002`**. That gives 775 on directories and 664 on files, so the group can write.
- TRaSH's fix-up commands (verbatim from `includes/file-and-folder-structure/permissions.md`):
  ```bash
  sudo chown -R $USER:$USER /data
  sudo chmod -R a=,a+rX,u+w,g+w /data
  ```
  On Unraid the equivalent is `chown -R nobody:users /mnt/user/data/` with the same chmod.
- **Exception:** Seerr ignores PUID/PGID. It runs as UID 1000 (`node`), so its config dir must be `chown 1000:1000`.
- Sources:
  - https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/ (read via the GitHub source: https://github.com/TRaSH-Guides/Guides/tree/master/docs/File-and-Folder-Structure)
  - https://trash-guides.info/File-and-Folder-Structure/Hardlinks-and-Instant-Moves/
  - To verify it works, use the TRaSH page "Check-if-hardlinks-are-working", e.g. `ls -li` link counts or `stat`.

---

## 7. Remote access and security

| Method | Use it for | Notes |
|---|---|---|
| **Plex built-in Remote Access** (forward TCP 32400 on the router, or UPnP) | **Streaming Plex** to you and your friends away from home | The simplest and ToS-clean option. Needs Plex Pass (owner) or RWP (viewer) for video. **If your ISP uses CGNAT**, Plex falls back to the **Relay, capped at about 1–2 Mbps**, which means poor quality. Ask the ISP for a public IPv4, or use a VPS/WireGuard tunnel or IPv6. https://natchecker.com/blog/plex-remote-access, https://support.plex.tv/articles/200931138-troubleshooting-remote-access/ |
| **Tailscale** (free Personal plan: **6 users, unlimited devices** since Apr 2026) | **You** reaching Sonarr, Radarr, qBittorrent, SAB and SSH from your phone. A few family members reaching Seerr or Jellyfin. | Zero open ports. Very beginner-friendly. It's no longer a reliable way around the Plex paywall (see §1.1). https://tailscale.com/blog/pricing-v4, https://tailscale.com/pricing |
| **Reverse proxy** (Nginx Proxy Manager, the easiest UI; Caddy, the simplest config with auto-HTTPS; Traefik, label-driven and more complex) plus your own domain | Exposing **Seerr** (and optionally Jellyfin) publicly for friends | Put it behind HTTPS, keep the app's own login (Seerr uses Plex login), and optionally add Authelia or Authentik for SSO/2FA. Expose **only** Seerr, never the *arrs. https://selfhostable.dev/blog/caddy-vs-nginx-proxy-manager-vs-traefik-reverse-proxy-showdown-2026/, https://homelabaddiction.com/nginx-proxy-manager-vs-caddy-vs-traefik/ |
| **Cloudflare Tunnel** | Fine for **Seerr** or dashboards (small web traffic) | **Streaming video (Plex or Jellyfin) through Cloudflare's proxy or tunnel is widely considered a ToS violation**, and Jellyfin's community rules explicitly call it out. Don't route Plex through it. https://community.cloudflare.com/t/confusion-about-tos-in-relation-to-using-cloudflared-tunnel-for-media-streaming/839900, https://instatunnel.substack.com/p/the-anti-cloudflare-strategy-getting |

**Security best practices (community consensus):**
1. **Never port-forward** Sonarr, Radarr, Prowlarr, Bazarr, qBittorrent, SABnzbd, NZBGet, Portainer or dashboards. Reach them via LAN or Tailscale.
   - About 300,000 exposed Plex servers turned up in 2026 scans (https://cybernews.com/security/plex-security-alert-urges-servers-update/). Exposed *arr and download-client UIs are routinely found and abused.
2. Keep **authentication enabled** in every *arr ("Forms" login; Sonarr v4 and Radarr v5+ require it). Change qBittorrent's random default password.
3. **Keep things updated**, but deliberately: SABnzbd RCE fixes (Aug/Sep 2026), Plex security patches (2025 and 2026). Use Diun or WUD notifications, or the maintained Watchtower fork with a schedule.
4. Turn on **2FA on your Plex account**. The Sep 2025 breach forced password resets. https://www.malwarebytes.com/blog/news/2025/09/plex-users-reset-your-password
5. Be careful with third-party add-ons that hold all your API keys (Huntarr, Feb 2026).
6. Put only qBittorrent behind the VPN, and bind it to the tunnel (Gluetun does this).

---

## 8. Mobile apps

| Need | App | Status |
|---|---|---|
| **Request content (users)** | **Plex app + Watchlist.** With Seerr's **Plex Watchlist Auto-Request**, anything a user adds to their Plex Watchlist is requested automatically. | Works on phones and TVs. This is the most "it just works" option for family. It needs the user to have signed into Seerr once and to hold the auto-request permission (`docs/using-seerr/plex/watchlist-auto-request.md` in the Seerr repo). |
| Request content (users) | **Seerr web UI**, installable as a PWA (add to home screen) | No official native app. The web UI is mobile-friendly. |
| Admin: Android | **nzb360** | Mature, paid; covers Sonarr, Radarr, Lidarr, download clients, Prowlarr and Seerr. Actively maintained per 2026 comparisons. |
| Admin: iOS | **Ruddarr** (free, open source; Sonarr and Radarr only), **Helmarr** | Ruddarr last released in early July 2026 per third-party coverage. |
| Admin: cross-platform | **Arrcade** | A new project positioning itself as the LunaSea successor. Claims come from its own blog (vendor bias). |
| Admin (old) | **LunaSea** | **Discontinued.** Repo archived 3 Apr 2025, hosted services shut down 30 Apr 2025. |
| Stats | Tautulli web UI (or the "Tautulli Remote" app) | Active |

Sources:
- https://arrcade.co.uk/blog/what-replaced-lunasea (vendor)
- https://arrcade.co.uk/blog/ruddarr-vs-helmarr-vs-nzb360-vs-arrcade (vendor)
- https://helmarr.com/blog/best-ios-apps-sonarr-radarr-2026 (vendor)
- https://apps.apple.com/rs/app/ruddarr/id6476240130

---

## 9. Common beginner pitfalls

1. **Separate volume mounts** (`/movies`, `/tv`, `/downloads`), which break hardlinks and atomic moves. You get copies, doubled disk usage and slow imports. Use one `/data` (see §6).
2. **Container paths differ between apps**, so you end up needing Remote Path Mappings. Fix the mounts instead.
3. **Mismatched PUID/PGID or UMASK**, causing "Access denied" on import or Plex not seeing files.
4. **A VPN on the whole host**, which breaks Plex remote access and metadata. Put only the torrent client behind Gluetun.
5. **Torrenting on public trackers without a VPN**, which brings ISP or DMCA notices. The reverse problem is a VPN with no port forwarding: slow or no seeding, bad ratio on private trackers.
6. **Exposing *arr or downloader UIs to the internet** (see §7), or running unaudited add-ons (Huntarr).
7. **Using containrrr/watchtower** (archived), or blind auto-updates that break things. Pin major versions where it matters. Re-read release notes (Radarr v6, Seerr migration, Jellyfin 12).
8. **Still running Overseerr or Jellyseerr.** Migrate to Seerr, and note it runs as UID 1000 with `init: true`.
9. **Plex metadata or appdata on a spinning HDD, or on an Unraid array without cache**, which makes everything sluggish.
10. **Expecting 4K HDR transcoding on an old CPU without Plex Pass HW transcoding**, or buying an "F" CPU with no iGPU, or an AMD GPU for Plex.
11. **PGS subtitles triggering burn-in transcodes.** Prefer SRT subtitles, and use clients that direct-play (Apple TV 4K, Shield, recent Fire TV or Google TV).
12. **Plex Relay** (CGNAT) giving 1–2 Mbps "remote" streams. Check the Remote Access status page.
13. **Over-strict quality profiles**, so nothing is ever grabbed. Or no profiles at all, so you get junk or fake releases. Start from the TRaSH or Recyclarr templates.
14. **No backups of appdata.** Parity and RAID are not a backup.
15. **Windows + Docker Desktop with media on NTFS drives**: no hardlinks and file-watch issues.
16. **Wrong expectations about the Tailscale "free Plex remote" hack**, which reportedly broke in 2026.
17. **Plex claim token expires in about 4 minutes.** Grab a fresh one from plex.tv/claim right before first `docker compose up`, or sign in via `http://<server-ip>:32400/web` on the LAN.
18. **Not mapping the iGPU** into the Plex container (`devices: - /dev/dri:/dev/dri`) or not enabling "Use hardware acceleration" in Plex's transcoder settings, which leaves HW transcoding unused.

Sources:
- https://corelab.tech/arr-stack-docker-compose-guide/
- https://talos.tools/blog/arr-stack-complete-guide
- https://mroczek.dev/articles/hardened-arr-stack/
- https://corelab.tech/plexoptimization/
- the TRaSH Guides pages cited above

---

## 10. All-in-one starter projects

| Project | What it is | Status | Recommended? |
|---|---|---|---|
| **YAMS** ("Yet Another Media Server"), https://yams.media, https://github.com/rogsme/yams | Bash installer that writes a compose stack: Gluetun, qBittorrent, SABnzbd, Sonarr, Radarr, Lidarr, Bazarr and Prowlarr, a choice of **Jellyfin (recommended), Emby or Plex**, Portainer and Watchtower. Follows hardlink best practice. | Active: latest commit 10 Sep 2026 (bumped Gluetun to v3.41.3). Targets Debian 13 and Ubuntu 24.04 per current docs (older README text says Debian 11/12, Ubuntu 22.04). Seerr/Jellyseerr is **not** included by default; the docs show how to add custom containers. | **Yes, the most beginner-friendly.** Add Seerr yourself. Check which Watchtower image it uses, and swap to `nickfedor/watchtower` or Diun if it's still `containrrr`. |
| **Ultimate Arr Stack** (Pharkie), https://github.com/Pharkie/ultimate-arr-stack | Compose stack: Jellyfin, Sonarr, Radarr, Prowlarr, Bazarr, **Seerr**, qBittorrent, SABnzbd, Gluetun, Pi-hole, Cloudflare Tunnel, Tailscale | Active (about 700 commits, Renovate updates). Jellyfin-first, but Plex can be swapped in. | Good reference. **Don't** route Plex video through its Cloudflare Tunnel. |
| **MediaStack** (geekau), https://github.com/geekau/mediastack | Big compose collection with SWAG, Authelia and Heimdall; Plex and Jellyfin | Active but complex. Had issues with the retired Readarr image. | Intermediate users |
| **Saltbox**, https://github.com/saltyorg/Saltbox | Ansible-based full media server (Ubuntu 24.04/26.04), heavily opinionated, cloud/dedicated-server heritage | Active | Not for beginners on an old PC |
| **automation-avenue/arr-new**, https://github.com/automation-avenue/arr-new | "New ARR stack 2026" compose, a YouTube companion | Active | Reference |
| **TRaSH Guides example compose** (hotio images) | The canonical folder and permission model | Active | **Use as the source of truth** |
| **corelab.tech compose generator**, https://corelab.tech/arr-stack-docker-compose-guide/ | Web generator for arr compose files | 2026 | Handy reference |

**Community advice:** starter projects are fine for getting running quickly. Still, **read TRaSH's folder and permissions guide and understand your compose file**, because you'll be the one debugging it. Many people start with YAMS or a template and then maintain their own compose file.

---

## 11. Minimal compose sketch (illustrative, Ubuntu/Debian host)

```yaml
# Illustrative only: pin tags, set your own TZ, and fill in secrets via .env
services:
  gluetun:
    image: qmcgaw/gluetun:v3.41.3
    cap_add: [NET_ADMIN]
    devices: [/dev/net/tun:/dev/net/tun]
    environment:
      - VPN_SERVICE_PROVIDER=protonvpn     # or private internet access, airvpn...
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=${WG_KEY}
      - PORT_FORWARD_ONLY=on               # Proton: only P2P/port-forward servers
      - VPN_PORT_FORWARDING=on
      - VPN_PORT_FORWARDING_UP_COMMAND=/bin/sh -c 'wget -O- --retry-connrefused --post-data "json={\"listen_port\":{{PORT}},\"current_network_interface\":\"{{VPN_INTERFACE}}\",\"random_port\":false,\"upnp\":false}" http://127.0.0.1:8080/api/v2/app/setPreferences 2>&1'
    ports: ["8080:8080"]                   # qBittorrent WebUI is published here
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    network_mode: "service:gluetun"
    environment: [PUID=1000, PGID=1000, UMASK=002, TZ=Etc/UTC, WEBUI_PORT=8080]
    volumes: ["/docker/appdata/qbittorrent:/config", "/data/torrents:/data/torrents"]
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    environment: [PUID=1000, PGID=1000, UMASK=002, TZ=Etc/UTC]
    volumes: ["/docker/appdata/sonarr:/config", "/data:/data"]
    ports: ["8989:8989"]
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    environment: [PUID=1000, PGID=1000, UMASK=002, TZ=Etc/UTC]
    volumes: ["/docker/appdata/radarr:/config", "/data:/data"]
    ports: ["7878:7878"]
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    environment: [PUID=1000, PGID=1000, UMASK=002, TZ=Etc/UTC]
    volumes: ["/docker/appdata/prowlarr:/config"]
    ports: ["9696:9696"]
  seerr:
    image: ghcr.io/seerr-team/seerr:latest
    init: true                             # required; runs as UID 1000, no PUID/PGID
    environment: [TZ=Etc/UTC]
    volumes: ["/docker/appdata/seerr:/app/config"]   # chown -R 1000:1000 this dir
    ports: ["5055:5055"]
  plex:
    image: lscr.io/linuxserver/plex:latest
    network_mode: host
    devices: ["/dev/dri:/dev/dri"]         # Intel Quick Sync (needs Plex Pass to use)
    environment: [PUID=1000, PGID=1000, UMASK=002, TZ=Etc/UTC, VERSION=docker, PLEX_CLAIM=${PLEX_CLAIM}]
    volumes: ["/docker/appdata/plex:/config", "/data/media:/data/media"]
```

Notes:
- The Gluetun `UP_COMMAND` shape follows the Gluetun wiki's qBittorrent example; check the wiki for the current exact string.
- The qBittorrent WebUI must allow localhost auth bypass for the port-update command to work.
- Add SABnzbd (`/data/usenet:/data/usenet`), Bazarr, Unpackerr, Recyclarr and Tautulli as needed.

---

## 12. Could not verify / caveats

- **Plex's official plans page and blog (plex.tv) could not be fetched.**
  - Prices and dates came from search snippets of the Plex blog and multiple news outlets (9to5Mac, HowToGeek, Android Authority, XDA, TheDesk). They agree with each other: $6.99/mo, $69.99/yr, $249.99 5-year, $749.99 lifetime from 1 Jul 2026, RWP $2.99/$29.99 from 1 Jun 2026.
  - The exact Plex Pass feature list (e.g. whether remote *music and photo* playback stays free) was **not** verified first-hand.
- **Which Plex client platforms enforce the remote paywall as of Sep 2026:** Roku (Nov 2025) and smart TVs and consoles (23 Mar 2026) are confirmed. Fire TV is reported enforced with the redesign. Apple TV, Android TV and third-party API clients (Infuse etc.) were announced "for 2026", and I could not confirm whether each is done yet.
- **Tailscale "LAN networks" bypass:** the guide author reports it "may no longer work" in 2026. It isn't proven dead for every client.
- **Unraid pricing:** $49 / $109 / $249 plus $36/yr is from Unraid's pricing blog. Lifetime at $249 is confirmed by Summer Sale 2026 coverage. One third-party review site listed different numbers ($59/$89/$129), which I consider unreliable. Check https://unraid.net/pricing before buying.
- **Plex 2026 security patch version** (reported as PMS 1.43.3, Aug/Sep 2026) came from secondary coverage; the primary article was blocked.
- **Plex HDR tone-mapping generation requirements** (Windows needs Tiger Lake or newer; Linux supports older chips) are from secondary sources and Plex support-page snippets.
- **Quick Sync stream counts** are community estimates, not benchmarks.
- **Lidarr metadata health in Sept 2026:** reliability problems were reported through 2025–2026, and current status is unconfirmed.
- **FlareSolverr effectiveness:** the project is releasing again (v3.5.x in 2026), but real-world success against Cloudflare varies by indexer.
- **Mobile app claims** (Ruddarr release cadence, Arrcade's cross-platform scope) come from vendor or competitor blogs.
- **YAMS supported OS and Watchtower image:** the README and current docs disagree slightly, and yams.media was blocked.
- **VPN port-forwarding list:** ProtonVPN, PIA and AirVPN are well established. Windscribe and TorGuard were not re-verified for 2026.
- **Usenet pricing** varies constantly with promotions; the numbers are ballpark only.
