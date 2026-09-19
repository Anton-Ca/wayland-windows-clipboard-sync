# Bidirectional Clipboard Sync (Ubuntu Wayland <-> Windows)

A zero-latency, event-driven, background clipboard synchronization system between an Ubuntu client (GNOME/Wayland) and a Windows host (e.g., Moonlight session) connected over SSH.

Especially useful if your tunneling workflow does not allow for native clipboard syncing. This system has not been properly tested on other than the creators system, so feel free to play around with it, but if you're unsure it might be best to contact the creator for verification before you download and run any code on your own system.

---

## Key Features

* **True 1-Keybind Native Sync:** Highlight and press `Ctrl + C` on either machine -> press `Ctrl + V` on the other.
* **No UI Flickering or Focus Loss:** Compiled C# binaries on Windows and native Wayland daemons on Ubuntu run completely headlessly in the background.
* **0% CPU Idle:** Uses Win32 API clipboard event listeners and socket events instead of aggressive CPU-bound polling.
* **Infinite Loop & Ping-Pong Protection:** Strict UTF-8 newline normalization (`\r\n` -> `\n`) and deduplication checks prevent infinite loop back-and-forth copying.

---

## Architecture Overview

```
[ Ubuntu Client ]                                        [ Windows Host ]
+----------------------+                                 +----------------------+
|  wl-paste / GTK      |                                 |  Win32 Clipboard     |
|         |            |                                 |       |              |
|  sync_daemon.py      | -- SSH (Port 2222 / SSH-In) ->  |  to_win.txt          |
|         |            |                                 |  SetClip.exe         |
|         |            |                                 |       |              |
|  127.0.0.1:9999      | <- Reverse SSH Tunnel (9999) -- |  WatchWin.exe        |
+----------------------+                                 +----------------------+
```

1. **Ubuntu -> Windows:** `sync_daemon.py` watches the Wayland selection. When you press `Ctrl + C` on Ubuntu, it sends the sanitized text over SSH to `C:\Users\<user>\.clip\to_win.txt` and triggers `SetClip.exe` via Windows Scheduled Tasks.
2. **Windows -> Ubuntu:** `WatchWin.exe` listens to Win32 `WM_CLIPBOARDUPDATE` messages. When you press `Ctrl + C` on Windows, it pushes the text across an encrypted reverse SSH tunnel (port `9999`) directly into the socket server inside `sync_daemon.py`, which updates `wl-copy`.

---

## Prerequisites

* **Ubuntu:** Ubuntu 20.04+ running GNOME / Wayland.
* **Windows:** Windows 10/11 with OpenSSH Server installed.
* **SSH Key Auth:** Passwordless SSH key authentication configured from Ubuntu to Windows.

---

## Quickstart

### On Windows (Host)
Open PowerShell as Administrator and run:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-host.ps1
```

### On Ubuntu (Client)
Open terminal and run:
```bash
chmod +x setup-client.sh
./setup-client.sh
```

---

## Detailed Setup Instructions

### Step 1: Configure the Windows Host

1. Open **PowerShell as Administrator** on your Windows host.
2. Save and run `setup-host.ps1`.

**What this script does:**
* Creates directory `C:\Users\<user>\.clip\`.
* Compiles `SetClip.exe` and `WatchWin.exe` as windowless GUI binaries using the built-in .NET compiler.
* Registers `PasteWinClip` as a Scheduled Task to update the Windows clipboard instantly.
* Registers `WatchWinClip` to run `WatchWin.exe` silently upon Windows user login.

---

### Step 2: Configure the Ubuntu Client

1. Open a terminal on your Ubuntu machine.
2. Save `setup-client.sh` to your working directory, make it executable, and run it:
```bash
chmod +x setup-client.sh
./setup-client.sh
```
3. When prompted, enter your Windows IP/Host, SSH port, and Windows username.

**What this script does:**
* Installs required packages (`wl-clipboard`, `python3`, `openssh-client`).
* Verifies passwordless SSH access to Windows.
* Generates `~/sync_daemon.py` with your custom connection variables.
* Generates `~/start-clip-sync.sh` to manage background sub-daemons and the reverse SSH tunnel.
* Configures GNOME Autostart (`~/.config/autostart/clip-sync.desktop`) so the service launches automatically on login.

---

## Managing and Running the Sync

### Testing / Manual Execution

To test the synchronization in real time or debug issues, run the launcher script directly from your terminal:

```bash
~/start-clip-sync.sh
```

* To stop the daemon when running manually, press **`Ctrl + C`**. It will terminate cleanly without generating core dumps or leaving orphaned background jobs.

### Checking Autostart Status

The sync script automatically starts in the background whenever you log into Ubuntu. To check if the background processes are actively running:

```bash
pgrep -fl sync_daemon
```

### Stopping or Restarting the Daemon

If you need to stop or restart the clipboard synchronization service manually on Ubuntu:

```bash
# Stop all active clipboard sync processes and tunnels
fuser -k 9999/tcp 2>/dev/null
pkill -f sync_daemon 2>/dev/null
pkill -f start-clip-sync 2>/dev/null

# Restart the service in the background
nohup ~/start-clip-sync.sh >/dev/null 2>&1 &
```

---

## File Structure Reference

| System | Path | Description |
| :--- | :--- | :--- |
| **Ubuntu** | `~/sync_daemon.py` | Core Python daemon (socket receiver & clipboard watcher). |
| **Ubuntu** | `~/start-clip-sync.sh` | Main process controller and reverse SSH tunnel loop. |
| **Ubuntu** | `~/.config/autostart/clip-sync.desktop` | GNOME autostart entry for automatic boot execution. |
| **Windows** | `C:\Users\<user>\.clip\SetClip.exe` | Headless C# binary that writes incoming text to clipboard. |
| **Windows** | `C:\Users\<user>\.clip\WatchWin.exe` | Headless C# binary that listens for Win32 copy events. |
| **Windows** | `C:\Users\<user>\.clip\to_win.txt` | Temporary staging file for incoming clipboard data. |

---

## Security & Privacy Considerations

* **Staging File:** Incoming clipboard text on Windows is written temporarily to `C:\Users\<user>\.clip\to_win.txt`. Avoid copying sensitive passwords or raw private keys across the bridge if local disk storage is a concern.
* **Socket Binding:** The socket listener on Ubuntu binds strictly to `127.0.0.1:9999` (loopback interface only). It is designed for single-user desktops.
* **Windows Defender:** `setup-host.ps1` compiles C# binaries using standard .NET framework calls (`Add-Type`). If Windows Defender or AMSI blocks script execution, temporarily unblock execution policy using `Set-ExecutionPolicy Bypass -Scope Process`.
