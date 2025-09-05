# Socat Manager

⚡ A simple, centralized `socat` manager for Linux. Solves the classic problem of Docker containers being unable to access services listening on the host's `localhost` (127.0.0.1).

This project provides a one-click installation script to set up a `systemd` service that manages multiple `socat` port forwarding rules from a single, easy-to-edit configuration file.

---

## The Problem It Solves

By default, Docker containers on Linux cannot connect to services that are bound to the host machine's loopback address (`127.0.0.1`). This is a security feature, but it creates a challenge when you want a container (like a reverse proxy) to access a service running on the host without exposing that service to other networks.

For example:
- A **Nginx Proxy Manager** container needs to forward traffic to a **X-UI** panel running on the host at `127.0.0.1:5000`.
- A web application in a container needs to connect to a database running on the host at `127.0.0.1:3306`.

This tool creates a clean and persistent "bridge" for such scenarios.

## How It Works

The script sets up a single `systemd` service (`socat-manager.service`) that reads a configuration file located at `/etc/socat/forwards.conf`. For each rule defined in the config file, it starts a `socat` process in the background.

This creates a stable and manageable way to forward traffic from an IP accessible by Docker containers (e.g., the Docker bridge gateway `172.17.0.1`) to the host's `127.0.0.1`.

**Traffic Flow:**
`[Docker Container]` -> `[Host IP on Docker Bridge (e.g., 172.17.0.1)]` -> `[socat process]` -> `[Host Service on 127.0.0.1]`

## 🚀 Quick Start: One-Click Installation

Run the following command as root or with `sudo` to install the Socat Manager on your Debian-based or RHEL-based system. The script will automatically install `socat` if it's not present.

```bash
bash <(curl -sL https://raw.githubusercontent.com/YourGitHubUsername/socat-manager/main/install_socat_manager.sh)
```
**Note:** Please replace `YourGitHubUsername` with your actual GitHub username once you've created the repository.

## ⚙️ Configuration

After installation, all you need to do is edit the configuration file to add your forwarding rules.

1.  **Open the configuration file:**
    ```bash
    sudo nano /etc/socat/forwards.conf
    ```

2.  **Add your rules.** The format for each line is:
    `<Listen_IP>:<Listen_Port>:<Forward_IP>:<Forward_Port>`

    **Example:**
    To forward traffic from `172.17.0.1:5000` to `127.0.0.1:5000`:
    ```
    # Socat Forwarding Rules
    #
    # Format: <Listen_IP>:<Listen_Port>:<Forward_IP>:<Forward_Port>
    # Lines starting with # are ignored. Blank lines are ignored.
    
    # Forward port 5000 for X-UI panel
    172.17.0.1:5000:127.0.0.1:5000
    
    # Forward port 3306 for a local database
    # 172.17.0.1:3306:127.0.0.1:3306
    ```

3.  **Restart the service** to apply the changes:
    ```bash
    sudo systemctl restart socat-manager.service
    ```

## 🛠️ Managing the Service

This is a standard `systemd` service. You can manage it with the following commands:

-   **Check the status:**
    ```bash
    sudo systemctl status socat-manager.service
    ```

-   **View logs:**
    ```bash
    sudo journalctl -u socat-manager.service -f
    ```

-   **Stop the service:**
    ```bash
    sudo systemctl stop socat-manager.service
    ```

-   **Start the service:**
    ```bash
    sudo systemctl start socat-manager.service
    ```

## 卸载 (Uninstall)

If you wish to remove the Socat Manager:

1.  **Stop and disable the service:**
    ```bash
    sudo systemctl stop socat-manager.service
    sudo systemctl disable socat-manager.service
    ```

2.  **Remove the files:**
    ```bash
    sudo rm /etc/systemd/system/socat-manager.service
    sudo rm /usr/local/bin/socat-manager.sh
    sudo rm -r /etc/socat
    ```
3.  **Reload the systemd daemon:**
    ```bash
    sudo systemctl daemon-reload
    ```

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
