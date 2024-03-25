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
