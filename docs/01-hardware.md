# 1. Hardware and BIOS

Target machine: the old gaming PC.

| Part | Status |
|---|---|
| CPU | i7-8700K, 6C/12T, **UHD 630 iGPU**. Quick Sync handles HEVC 10-bit. Plenty for this job. |
| Motherboard | ASUS ROG Strix Z370-E Gaming |
| RAM | 16 GB DDR4. Plenty (the whole stack uses ~3–5 GB). |
| GPU | GTX 1070 Ti. **Not needed**, see below. |
| Network | Intel I219-V gigabit, wired. Use this, not Wi-Fi. |
| PSU | Corsair CX650M, fine |
| Drives | **None.** The originals moved to the new build. Buy the drives below. |

## Shopping list

| Item | Recommendation | Notes |
|---|---|---|
| Boot/app SSD | 500 GB–1 TB, SATA or NVMe | Holds Ubuntu, app databases and Plex metadata (which grows to tens of GB). The Z370-E has two M.2 slots. |
| Media HDD | One **12–20 TB CMR** drive | Examples: WD Red Plus/Pro, Seagate IronWolf/Exos, WD Ultrastar. Recertified enterprise drives are popular and cheap. **Avoid SMR drives**, including plain "WD Red" (non-Plus). Check the spec sheet. |
| Ethernet cable | Any Cat5e/Cat6 | Server wired to the router |
| USB stick | 8 GB or more | For the Ubuntu installer (temporary) |

Rough sizes: a 1080p movie is 4–10 GB and a 1080p TV episode is 1–3 GB. So 16 TB holds roughly 1,000+ movies plus a good number of shows.

## Pull the GTX 1070 Ti (recommended)

The iGPU does all the transcoding. The 1070 Ti would add ~10–15 W at idle, heat and noise, and NVIDIA driver setup on Linux, and it isn't needed. With it removed, the iGPU is the only display adapter and "just works".

If you keep it anyway, you **must** enable the iGPU in the BIOS (below), or Plex won't see Quick Sync.

## Install the drives

1. Install the SSD in an M.2 slot (or a SATA port) and the HDD on a SATA port.
2. Check the motherboard manual: on Z370 boards, using some M.2 slots disables certain SATA ports. Put the HDD on a port that stays active.
3. Connect a monitor to the **motherboard's** HDMI/DisplayPort (only needed during install). Connect Ethernet.

## BIOS settings (ASUS UEFI, press `Del` at boot, then `F7` for Advanced Mode)

| Setting | Where | Value |
|---|---|---|
| iGPU on | Advanced → System Agent (SA) Configuration → Graphics Configuration → **Primary Display** | `CPU Graphics` (or `Auto` if the 1070 Ti is removed) |
| iGPU alongside the dGPU (only if keeping the 1070 Ti) | same menu → **iGPU Multi-Monitor** | `Enabled` |
| Auto power-on after an outage | Advanced → APM Configuration → **Restore AC Power Loss** | `Power On` |
| Wake-on-LAN (optional) | Advanced → APM Configuration → **Power On By PCI-E** | `Enabled` |
| Memory XMP | Ai Tweaker → Ai Overclock Tuner | Leave at `Auto` (2133 MHz). Stability beats speed for a server. |
| Boot mode | Boot → CSM | `Disabled` (pure UEFI). Secure Boot can stay on; Ubuntu supports it. |

Save with `F10`.

After Ubuntu is installed, verify the iGPU with `ls /dev/dri`. You should see `card0` (or `card1`) and **`renderD128`**. `scripts/bootstrap.sh` checks this for you.

Next: [02-install-ubuntu.md](02-install-ubuntu.md)
