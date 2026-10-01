# Private DNS Server (Mac 1) - SCRIPT 1 Documentation

## 1. dnsmasq Commands

Since we are binding to port 53 (the standard DNS port), `dnsmasq` requires root privileges (`sudo`). We have saved the configuration file at `config/dnsmasq.conf`.

**Start the DNS server (run in foreground for testing):**
```bash
sudo /opt/homebrew/sbin/dnsmasq -d -C /Users/omkarshukla/Documents/CN_Project/config/dnsmasq.conf
```
*(Press `Ctrl+C` to stop it.)*

**Run it as a background daemon:**
```bash
sudo /opt/homebrew/sbin/dnsmasq -C /Users/omkarshukla/Documents/CN_Project/config/dnsmasq.conf
```

**Stop the DNS server (if running in background):**
```bash
sudo killall dnsmasq
```

**Restart the DNS server:**
```bash
sudo killall dnsmasq && sudo /opt/homebrew/sbin/dnsmasq -C /Users/omkarshukla/Documents/CN_Project/config/dnsmasq.conf
```

**Check status:**
```bash
pgrep -fl dnsmasq
```

---

## 2. Client Configuration

For Mac 2, 3, and 4 to resolve the domains properly, you need to configure them to use your Mac 1 (`10.7.15.236`) as their DNS Server.

**How to set this up on teammates' Macs:**
1. Open **System Settings** > **Wi-Fi**.
2. Click **Details...** next to the connected Wi-Fi network.
3. Select **DNS** from the sidebar.
4. Click the **+** button under "DNS Servers" and add `10.7.15.236`.
5. Remove or move this to the top of the list if there are other DNS servers.
6. Click **OK**.

---

## 3. Testing Commands

Once the DNS server is running and clients are configured, verify it works using these commands from your machine or your teammates' machines:

```bash
dig app.team1.test @10.7.15.236
dig api.team1.test @10.7.15.236
nslookup app.team1.test 10.7.15.236
```
*(Removing `@10.7.15.236` tests whether the system's DNS settings are correctly applying the new DNS server).*

---

## 4. Explanation: DNS vs TCP/HTTPS and DNS Ports

*   **DNS (Domain Name System)** operates primarily over **UDP port 53** (though it can use TCP port 53 for large responses). Its sole responsibility is to translate human-readable domain names (like `app.team1.test`) into IP addresses (like `10.7.17.151`).
*   **TCP (Transmission Control Protocol)** is the underlying reliable transport protocol used by HTTP/HTTPS. Once DNS provides the IP address, the client establishes a TCP connection (the 3-way handshake: SYN, SYN-ACK, ACK) to that IP.
*   **HTTPS (HTTP Secure)** operates over **TCP port 443** (or in our edge case, potentially `8443`). It builds on top of TCP by initiating a TLS (Transport Layer Security) handshake to encrypt the application payload.
*   **The Flow**: The client first queries DNS (UDP 53) to find out *where* `app.team1.test` is. DNS answers `10.7.17.151`. The client then sends a TCP SYN to `10.7.17.151` on port 443 to start the HTTPS connection. The DNS server is never involved in the HTTP/HTTPS traffic itself; it merely acts as the directory service.
