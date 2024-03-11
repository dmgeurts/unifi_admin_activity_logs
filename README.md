# unifi_admin_activity_logs
Trying to find a way to extract Admin Activity logs from a Unifi Controller

## Options in v8.0

There are no text files, no journal and there's no API that exposes the Admin Activity.

## Requirement

For multi-tenant deployments, and others who are security-minded, it's imperative to be able to feed Admin activity into a SIEM. This repo tries to provide a way to expose these logs in a way that is accessible/ingestable by a SIEM.

