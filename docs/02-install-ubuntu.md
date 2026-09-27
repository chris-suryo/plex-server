# 2. Install Ubuntu Server

Ubuntu Server LTS (24.04 or 26.04) with no desktop. You'll manage it over SSH from your main PC.

## Make the installer USB (on your Windows PC)

1. Download the **Ubuntu Server LTS** ISO: https://ubuntu.com/download/server
2. Flash it to the USB stick with [balenaEtcher](https://etcher.balena.io/) or [Rufus](https://rufus.ie/).

## Install

Boot the server from the USB (press `F8` at power-on for the ASUS boot menu). Then go through the installer:

| Screen | Choose |
|---|---|
| Language / keyboard | Your choice |
| Network | The wired interface should get an IP by DHCP. Note it. |
| Proxy / mirror | Defaults |
| **Storage** | *Use an entire disk* → pick the **SSD** (check the size and model). Keep *Set up this disk as an LVM group* ticked. **Do not pick the HDD.** It gets set up later. |
| Storage summary | The installer only gives `ubuntu-lv` part of the SSD. Either edit `ubuntu-lv` to use the max size here, or fix it after install (below). |
| Profile | Your name, server name (e.g. `mediaserver`), username, a strong password |
| Ubuntu Pro | Skip |
| **SSH** | ✅ *Install OpenSSH server* |
| Featured snaps | **Select none.** In particular, don't pick the `docker` snap. Docker comes from Docker's own repo later. |

Reboot and remove the USB stick when prompted.

## First login

Log in at the server's console once and run `ip -4 a` to get its IP address. From then on, work from your main PC:

```bash
ssh <username>@<server-ip>
```

Windows 10/11 has `ssh` built into PowerShell and Terminal.

## Post-install

```bash
# Use the whole SSD for the OS volume (skip if you already did it in the installer)
sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
df -h /

# Updates
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

Security updates install automatically (`unattended-upgrades` is on by default).

## Give the server a fixed IP

In your router's admin page, find the server in the DHCP client list and create a **DHCP reservation** (sometimes called a "static lease"). Plex port forwarding and your bookmarks depend on this IP never changing.

## Get this repo onto the server

The repo contains no secrets (those live in `.env`, which is git-ignored).

```bash
# If the repo is public:
git clone https://github.com/chris-suryo/plex-server.git ~/plex-server

# If it's private, the easiest way is the GitHub CLI:
sudo apt install -y gh
gh auth login          # follow the prompts (choose HTTPS, log in with a browser/code)
gh repo clone chris-suryo/plex-server ~/plex-server
```

Next: [03-storage.md](03-storage.md)
