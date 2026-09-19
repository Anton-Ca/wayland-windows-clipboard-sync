#!/bin/bash
set -e

echo "=========================================="
echo " Seamless Clipboard Sync - Ubuntu Setup "
echo "=========================================="

# 1. Interactive Parameters with generic defaults
read -p "Enter Windows IP / Host [default: 192.168.1.100]: " WIN_HOST
WIN_HOST=${WIN_HOST:-192.168.1.100}
# Make sure to switch out the local example IP 192.168.1.100
# to your public windows IP that you can find by googling "What's my IP?".

read -p "Enter Windows SSH Port [default: 22]: " WIN_PORT
WIN_PORT=${WIN_PORT:-22}

read -p "Enter Windows Username [default: $USER]: " WIN_USER
WIN_USER=${WIN_USER:-$USER}

LOCAL_USER=$(whoami)
HOME_DIR=$HOME

echo ""
echo "Configuration parameters:"
echo "  Local Ubuntu User: $LOCAL_USER ($HOME_DIR)"
echo "  Windows Target:    $WIN_USER@$WIN_HOST:$WIN_PORT"
echo ""

# 2. Package Dependency Checks
echo "[1/5] Checking and installing apt dependencies..."
sudo apt update
sudo apt install -y wl-clipboard python3 openssh-client

# 3. Passwordless SSH Verification
echo "[2/5] Verifying SSH connectivity to Windows host..."
if ssh -q -o BatchMode=yes -o ConnectTimeout=5 -p "$WIN_PORT" "$WIN_USER@$WIN_HOST" exit 2>/dev/null

   echo " -> WARNING: Passwordless SSH authentication failed."
       read -p "Would you like to setup SSH key copying now (ssh-copy-id)? (y/n): " SETUP_SSH
           if [[ "$SETUP_SSH" =~ ^[Yy]$ ]]

 "[3/5] Generating ~/sync_daemon.py..."
at << 'EOF' > "$HOME_DIR/sync_daemon.py"
!/usr/bin/env python3
import sys, time, socket, threading, subprocess, signal

PORT = 9999
WIN_USER = "__WIN_USER__"
WIN_HOST = "__WIN_HOST__"
WIN_PORT = "__WIN_PORT__"

last_text = ""
lock = threading.Lock()

def sanitize(text):
    if not text:
            return ""
                text = text.replace('\r\n', '\n').replace('\r', '')
                    replacements = {'\xa0': ' ', '“': '"', '”': '"', '‘': "'", '’': "'", '—': '-'}
                        for k, v in replacements.items():
                                text = text.replace(k, v)
                                    return text.strip()

                                    def get_ubuntu_clip():
                                        try:
                                                res = subprocess.run(["wl-paste", "-n"], capture_output=True, text=True, timeout=1)
                                                        return sanitize(res.stdout) if res.returncode == 0 else ""
                                                            except Exception:
                                                                    return ""

                                                                    def set_ubuntu_clip(text):
                                                                        try:
                                                                                p = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE)
                                                                                        p.communicate(input=text.encode('utf-8'))
                                                                                            except Exception:
                                                                                                    pass

                                                                                                    def send_to_windows(text):
                                                                                                        cmd = [
                                                                                                                "ssh", "-o", "ConnectTimeout=3", "-p", WIN_PORT,
                                                                                                                        f"{WIN_USER}@{WIN_HOST}",
                                                                                                                                'powershell.exe -command "$input | Set-Content -Path C:\\Users\\' + WIN_USER + '\\.clip\\to_win.txt -Encoding UTFchtasks /run /tn PasteWinClip"'
                                                                                                                                    ]
                                                                                                                                        try:
                                                                                                                                                p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                                                                                                                                                        p.communicate(input=text.encode('utf-8'), timeout=4)
                                                                                                                                                            except Exception:
                                                                                                                                                                    pass

                                                                                                                                                                    def incoming_socket_listener():
                                                                                                                                                                        global last_text
                                                                                                                                                                            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                                                                                                                                                                                s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                                                                                                                                                                                    try:
                                                                                                                                                                                            s.bind(("127.0.0.1", PORT))
                                                                                                                                                                                                    s.listen(5)
                                                                                                                                                                                                        except Exception:
                                                                                                                                                                                                                return

                                                                                                                                                                                                                    while True:
                                                                                                                                                                                                                            try:
                                                                                                                                                                                                                                        conn, _ = s.accept()
                                                                                                                                                                                                                                                    data = conn.recv(65536).decode("utf-8", errors="ignore")
                                                                                                                                                                                                                                                                conn.close()
                                                                                                                                                                                                                                                                            if data:
                                                                                                                                                                                                                                                                                            clean_data = sanitize(data)
                                                                                                                                                                                                                                                                                                            with lock:
                                                                                                                                                                                                                                                                                                                                if clean_data and clean_data != last_text:
                                                                                                                                                                                                                                                                                                                                                        last_text = clean_data
                                                                                                                                                                                                                                                                                                                                                                                set_ubuntu_clip(clean_data)
                                                                                                                                                                                                                                                                                                                                                                                        except Exception:
                                                                                                                                                                                                                                                                                                                                                                                                    pass

                                                                                                                                                                                                                                                                                                                                                                                                    def outgoing_clip_watcher():
                                                                                                                                                                                                                                                                                                                                                                                                        global last_text
                                                                                                                                                                                                                                                                                                                                                                                                            last_text = get_ubuntu_clip()

                                                                                                                                                                                                                                                                                                                                                                                                                    while True:
                                                                                                                                                                                                                                                                                                                                                                                                                            time.sleep(0.8)
                                                                                                                                                                                                                                                                                                                                                                                                                                    current = get_ubuntu_clip()
                                                                                                                                                                                                                                                                                                                                                                                                                                            if current and current != last_text:
                                                                                                                                                                                                                                                                                                                                                                                                                                                        with lock:
                                                                                                                                                                                                                                                                                                                                                                                                                                                                        last_text = current
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        threading.Thread(target=send_to_windows, args=(current,), daemon=True).start()

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        def shutdown(signum, frame):
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            sys.exit(0)

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            if __name__ == "__main__":
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                signal.signal(signal.SIGINT, shutdown)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    signal.signal(signal.SIGTERM, shutdown)

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        t_in = threading.Thread(target=incoming_socket_listener, daemon=True)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            t_in.start()

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                outgoing_clip_watcher()
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                EOF

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                sed -i "s/__WIN_USER__/$WIN_USER/g" "$HOME_DIR/sync_daemon.py"
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                sed -i "s/__WIN_HOST__/$WIN_HOST/g" "$HOME_DIR/sync_daemon.py"
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                sed -i "s/__WIN_PORT__/$WIN_PORT/g" "$HOME_DIR/sync_daemon.py"
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                chmod +x "$HOME_DIR/sync_daemon.py"

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                # 5. Generate ~/start-clip-sync.sh
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                echo "[4/5] Generating ~/start-clip-sync.sh..."
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                cat << 'EOF' > "$HOME_DIR/start-clip-sync.sh"
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                #!/bin/bash
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                cleanup() {
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    pkill -P $$ 2>/dev/null
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        exit 0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        }
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        trap cleanup INT TERM EXIT

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        python3 $HOME/sync_daemon.py &

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        while true

F

sed -i "s/__WIN_USER__/$WIN_USER/g" "$HOME_DIR/start-clip-sync.sh"
sed -i "s/__WIN_HOST__/$WIN_HOST/g" "$HOME_DIR/start-clip-sync.sh"
sed -i "s/__WIN_PORT__/$WIN_PORT/g" "$HOME_DIR/start-clip-sync.sh"
sed -i "s|\$HOME|$HOME_DIR|g" "$HOME_DIR/start-clip-sync.sh"
chmod +x "$HOME_DIR/start-clip-sync.sh"

# 6. Configure GNOME Autostart
echo "[5/5] Configuring GNOME Autostart entry..."
mkdir -p "$HOME_DIR/.config/autostart"
cat << EOF > "$HOME_DIR/.config/autostart/clip-sync.desktop"
[Desktop Entry]
Type=Application
Name=Seamless Clipboard Sync
Exec=$HOME_DIR/start-clip-sync.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

echo ""
echo "=== Ubuntu Setup Completed Successfully ==="
echo "Generated files:"
echo "  - $HOME_DIR/sync_daemon.py"
echo "  - $HOME_DIR/start-clip-sync.sh"
echo "  - $HOME_DIR/.config/autostart/clip-sync.desktop"
