# unifi_admin_activity_logs
Trying to find a way to extract Admin Activity logs from a Unifi Controller

## Options in v8.0

There are no text files, journals or APIs which expose Admin Activity.

The Unifi Controller MongoDB contains a collection named `admin_activity_log`, here all admin activity log entries are stored.

## Requirement

For multi-tenant deployments, and others who are security-minded, it's imperative to be able to feed Admin activity into a SIEM. This repo tries to provide a way to expose these logs in a way that is accessible/ingestable by an SIEM.

## Solution

This script writes new admin activity logs found in the MongoDB collection `admin_activity_log` to file. If the log file doesn't exist it's created and logs from the last ten seconds are written to file. If the log file contains at least one log entry then this entry will be used as the timestamp to read the activity log from.

The log file duplicates the admin logs from the MongoDB database so a short log-rotation is advised to keep disk usage to a minimum.

The log file can be monitored using your favourite SIEM log-file watcher, some examples are Filebeat and Elastic Agent.

### Unifi doesn't log failed login attempts

The only solution I know of now (Q1 2024) is to front the Unifi UI with a reverse proxy and log the web requests. These can then be ingested by the same SIEM and compared to the admin activity logs reported by the Unifi Controller. This way HTTP error codes returned by the controller are logged. The client's real IP address must be parsed to the controller, to maintain visibility of the source IP address in the admin activity logs.

## Usage

Ensure to make the script executable after copying it to the desired location: 

```bash
sudo chmod +x /usr/local/bin/dump_admin_activity.sh
```

### Log file location

The script can create the log folder, but if running the script as non-root (advised) the user must either be a member of the syslog group or have sudo rights to create a folder under `/var/log`. Note that the name and location of the log folder are configurable in the script.

To create the log folder manually: 

```bash
sudo mkdir /var/log/unifi_admin_activity
sudo chown unifi:unifi /var/log/unifi_admin_activity
sudo chmod 750 /var/log/unifi_admin_activity
```

Consider the rights your log file watcher/scraper needs to read the log file, and adjust ownerships and privileges accordingly.

### Systemd service

Create the systemd service file, then reload the systemd daemon, enable and start the service: 

```bash
sudo vi /etc/systemd/system/unifi-admlog-export.service
sudo systemctl daemon-reload
sudo systemctl enable --now unifi-admlog-export.service
```

`stdout` of the service is logged to the journal, to tail the logs: 

```bash
sudo journalctl -fu unifi-admlog-export
```

### Manual test run

```bash
sudo -u unifi /usr/local/bin/dump_admin_activity.sh
```

It will keep running until you escape out of the while loop with `ctrl-c`.

## log rotation

Without log management the data duplication between the MongoDB ace database and the log file will consume disk space faster than without. Hence the log files don't need to be kept around for long, the advised log-rotation removes log files older than a few days.

`sudo vi /etc/logrotate.d/unifi_admin_activity` 

```text
/var/log/unifi_admin_activity/*.log {
    rotate 3
    daily
    create 640 unifi unifi
    missingok
    notifempty
}
```

## Reverse proxy

⚠️ When using a reverse proxy local to the Unifi Controller, one must ensure not to forward sessions to localhost as these are excluded from the Admin Activity log.

Another requirement is to pass the client real-ip address, else the Controller will log the IP address of the reverse proxy. This Nginx vhost `proxy_pass` snippet works for me, ymmv: 

```text
    # Redirect to Unifi Controller
    location / {
        proxy_pass       https://[public IP]:8443;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    }
```
