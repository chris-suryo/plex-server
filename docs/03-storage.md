# 3. Set up the media drive (`/data`)

The HDD is formatted as one ext4 filesystem mounted at `/data`. Downloads and the library both live on it. That's what lets Sonarr/Radarr **hardlink or instantly move** finished downloads instead of copying them. (Splitting them across drives or separate mounts is the #1 beginner mistake.)

> ⚠️ Formatting erases the drive. Triple-check the device name.

## 1. Find the HDD

```bash
lsblk -o NAME,SIZE,MODEL,TYPE,MOUNTPOINTS
```

The HDD is the big one with no mountpoints, e.g. `sda` at `16.4T`. The SSD shows `/` and `/boot` mounts. Below, replace **`sdX`** with your HDD's name.

## 2. Partition and format

```bash
sudo parted /dev/sdX --script mklabel gpt mkpart data ext4 0% 100%
# -m 0: don't reserve 5% for root (that's ~800 GB on a 16 TB data-only drive)
sudo mkfs.ext4 -L data -m 0 /dev/sdX1
```

## 3. Mount it at boot

```bash
sudo mkdir -p /data
UUID=$(sudo blkid -s UUID -o value /dev/sdX1)
echo "UUID=$UUID /data ext4 defaults,noatime,nofail 0 2" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo mount -a
df -h /data          # should show the HDD's size
```

`nofail` means the server still boots if the drive ever dies.

## 4. Don't let Docker start without the drive

If `/data` failed to mount, the apps would quietly download onto the SSD and fill it. This makes Docker wait for `/data` instead:

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
printf '[Unit]\nRequiresMountsFor=/data\n' | sudo tee /etc/systemd/system/docker.service.d/wait-for-data.conf
sudo systemctl daemon-reload
```

Docker may not be installed yet; that's fine. The drop-in takes effect once it is.

## 5. Drive health monitoring (recommended)

```bash
sudo apt install -y smartmontools
sudo smartctl -H /dev/sdX    # should say PASSED
```

`smartd` (installed with it) watches the drive in the background.

## 6. Run the bootstrap script

```bash
cd ~/plex-server
./scripts/bootstrap.sh
```

It installs Docker, creates `.env`, and builds the folder tree:

```
/data
├── torrents/{movies,tv}
├── usenet/{incomplete,complete/{movies,tv}}
└── media/{movies,tv}          <- Plex libraries point here
```

App settings go to `/docker/appdata/<app>` on the SSD. Log out and back in afterwards so you can run `docker` without `sudo`.

## Later: adding more drives

When the drive fills up, the common next step is **mergerfs + SnapRAID**. mergerfs pools several drives into one `/data`, and SnapRAID uses one drive as parity so a single disk failure doesn't lose the library. Mixed drive sizes are fine. See https://perfectmediaserver.com/. The hardlink rule still applies: use a mergerfs create policy that keeps a download and its library copy on the same disk (e.g. `epmfs`).

Next: [04-configure-apps.md](04-configure-apps.md)
