# Ironic All‑in‑One (AIO) Container

Single‑container OpenStack Ironic (API + Conductor) for standalone bare metal provisioning via Redfish virtual media. No Keystone, no PXE/DHCP infrastructure required.

## Why This Image

- **Standalone / noauth**: Simplest possible Ironic usage.
- **Single process**: API + Conductor launched together.
- **Redfish focus**: Only Redfish hardware + virtual media boot enabled.
- **Self‑maintaining DB**: Entry point creates/updates SQLite schema automatically.
- **Deterministic releases**: GitHub tags produce immutable image tags (`vX.Y.Z`, `X.Y`, `X`).
- **Fast local testing**: Minimal runtime dependencies; just mount config + DB file.

## Image & Tags

Published to GitHub Container Registry:

```
ghcr.io/mattcburns/ironic-aio
```

Tag strategy (from `docker-publish.yml`):

- `master` (latest state of the default branch)
- `vX.Y.Z` (full semver tag you push)
- `X.Y` and `X` convenience semver tags
- Commit SHA tag (e.g. `sha-<shortsha>`) for reproducibility

Example pulls:

```bash
docker pull ghcr.io/mattcburns/ironic-aio:master
docker pull ghcr.io/mattcburns/ironic-aio:v1.2.3
docker pull ghcr.io/mattcburns/ironic-aio:1.2
```

## Quick Start (Docker Run)

1. Ensure you have a config file and an empty DB file on the host (create the DB file with `touch` to avoid Docker mounting a directory):

```bash
cp ironic.conf.example ironic.conf
touch ironic.sqlite
```

2. Run the container (maps API 6385 + local httpboot 8080):

```bash
docker run -d --name ironic \
  -p 6385:6385 -p 8080:8080 \
  -v "$PWD/ironic.conf:/app/ironic.conf:ro" \
  -v "$PWD/ironic.sqlite:/app/ironic.sqlite" \
  ghcr.io/mattcburns/ironic-aio:master
```

3. Verify:

```bash
curl http://localhost:6385/v1          # API root
docker logs -f ironic | head -n 50     # recent startup logs
docker exec ironic baremetal driver list
```

## Compose Setup

This repo provides a minimal two-container setup:
- `ironic` (built from this repo) with `/app` bound to a host directory
- `nginx` serving the vmedia directory over HTTP

### Additional Files

To get provisioning to work, you will need to place a copy of the Ironic Python Agent (IPA)
iso into the vmedia/ipa folder and get yourself a cloud image (I suggest Ubuntu) to place
into vmedia.

IPA ISO: [ironic-iso](https://github.com/mattcburns/ironic-iso)
OS Image (.img): [ubuntu](https://cloud-images.ubuntu.com/noble/current/)

### Volume mounts (parameterized)

Host-side paths can be customized via environment variables:
- `IRONIC_HOST_DIR` (default `/opt/ironic`) → mounted to `/app`
- `IRONIC_CONF` (default `/opt/ironic/ironic.conf`) → mounted to `/app/ironic.conf` (read-only)
- `IRONIC_DB_FILE` (default `/opt/ironic/ironic.sqlite`) → mounted to `/app/ironic.sqlite`
- `IRONIC_VMEDIA_DIR` (default `/opt/ironic/vmedia`) → mounted to `/usr/share/nginx/html` (read-only)
  - This also needs to include a folder named `ipa` inside `vmedia` eg: `/opt/ironic/vmedia/ipa` for
    the Ironic Python Agent (IPA) iso

Create a `.env` file to set these variables:

```
cp .env.example .env
vi .env
```

Ensure your host directory contains a valid `ironic.conf` (you can start from `ironic.conf.example`):

```
mkdir -p /opt/ironic /opt/ironic/vmedia
cp ironic.conf.example /opt/ironic/ironic.conf
touch /opt/ironic/ironic.sqlite
```

### Run

```
docker compose up -d
docker compose ps
```

### Quick checks

```
curl -sSf http://localhost:6385/v1 || true
curl -I http://localhost:8080/
docker compose exec ironic baremetal driver list
```

### Notes

- The entrypoint requires `/app/ironic.conf`. It will initialize/upgrade the SQLite DB referenced in the config.
- If you bind mount a non-existent path for the SQLite DB on the host, Docker may create a directory; ensure the DB is a file.
On first start the entrypoint will:

- Parse DB path from `[database]` section of `ironic.conf`
- Create schema if the file is missing or empty
- Run an upgrade if the DB already exists
- Launch `ironic` (single process API + Conductor)

## Configuration

Mount your `ironic.conf` into `/app/ironic.conf` (read‑only recommended). To apply changes:

```bash
vim ironic.conf
docker restart ironic
docker logs -f ironic | grep -i 'Loading'  # optional validation
```

Minimal relevant defaults are already set (redfish only, json-rpc transport, sqlite). Adjust hardware driver settings as needed for your environment.

## Database Handling

SQLite file lives at `/app/ironic.sqlite` (derived from `connection = sqlite:////app/ironic.sqlite`). Important points:

- Pre‑create with `touch ironic.sqlite` before `docker run` so Docker mounts a file, not a directory.
- Entry point auto upgrades schema on each start.
- To reset: stop container, remove file, recreate empty file, start again.

Reset example:

```bash
docker stop ironic
rm -f ironic.sqlite
touch ironic.sqlite
docker start ironic
```

Manual operations (rarely needed):

```bash
docker exec ironic ironic-dbsync --config-file /app/ironic.conf upgrade
docker exec ironic ironic-dbsync --config-file /app/ironic.conf create_schema
```

## Release Automation

Two GitHub Actions workflows:

1. `docker-publish.yml` – builds image on pushes, PRs, and version tags; pushes on non‑PR events.
2. `release.yml` – creates a GitHub Release for `v*` tags with autogenerated notes and usage snippet.

To cut a release:

```bash
git tag v1.2.3
git push origin v1.2.3
```

This produces image tags: `v1.2.3`, `1.2`, `1`, plus the commit SHA.

## Upper Constraints

Uses upper-constraints.txt from [2025.2](https://raw.githubusercontent.com/openstack/requirements/refs/heads/stable/2025.2/upper-constraints.txt)

## Common Commands

```bash
# List nodes (after you create some)
curl http://localhost:6385/v1/nodes | jq

# Create a node (example, adjust driver-specific fields)
curl -X POST http://localhost:6385/v1/nodes -H 'Content-Type: application/json' \
  -d '{"driver":"redfish","name":"node01"}'

# Show enabled drivers
docker exec ironic baremetal driver list
```

## Troubleshooting

| Symptom | Cause | Fix |
+|---------|-------|-----|
+| Entry point error: "Expected SQLite database file but found a directory" | Forgot to `touch ironic.sqlite` before run | Stop container, remove directory, `touch ironic.sqlite`, re-run |
+| API not reachable on 6385 | Port not published | Include `-p 6385:6385` in run command |
+| Config changes ignored | Container caching old config | Ensure mount path is correct and restart container |

### API Security and Allowlist (nginx)

By default, the Ironic API is secured behind nginx with HTTP basic authentication. You can allowlist specific IPs or subnets to bypass authentication (for example, for the Ironic Python Agent or trusted networks).

- The allowlist is configured in `nginx.conf` in the `location /` block for the API reverse proxy. Look for the section marked `ALLOWLIST CONFIGURATION`.
- To allow an IP or subnet to bypass authentication, add an `allow` line (e.g., `allow 192.168.1.0/24;`).
- All other clients will be required to authenticate with HTTP basic auth.
- To require authentication for everyone, comment out all `allow` lines except `deny all;`.

#### Example allowlist section in `nginx.conf`:

```nginx
# --- ALLOWLIST CONFIGURATION ---
# Add or change allowed IPs/subnets below to bypass authentication.
# Example: allow 172.16.0.0/12; # Docker default bridge network range
# allow 192.168.1.0/24; # Example: custom subnet
satisfy any;
allow 172.16.0.0/12; # Docker default bridge network range
# allow 192.168.1.0/24; # Example: custom subnet
deny all;
# --- END ALLOWLIST CONFIGURATION ---
```

#### Setting up HTTP Basic Auth

1. Create an `htpasswd` file (requires Docker):

```bash
docker run --rm -it httpd:alpine htpasswd -Bbn ironicuser strongpassword > htpasswd
```

2. Mount the file in your `docker-compose.yml` under the nginx service:

```yaml
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./htpasswd:/etc/nginx/htpasswd:ro
```

3. Restart the nginx service:

```bash
docker compose restart nginx
```

### Enabling TLS (HTTPS) for the Ironic API

The Ironic API is served over HTTPS by default via nginx. You must provide SSL certificates for nginx to use. For development, self-signed certificates are sufficient. For production, use certificates from a trusted Certificate Authority (CA).

#### Generating Self-Signed Certificates (Development)

1. Create a directory for your SSL files (if not already present):

```bash
mkdir -p ssl
```

2. Generate a self-signed certificate and key:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/tls.key -out ssl/tls.crt \
  -subj "/CN=localhost"
```

- This creates `ssl/tls.crt` (certificate) and `ssl/tls.key` (private key).
- You can adjust the `-subj` to match your hostname or IP as needed.

3. The `docker-compose.yml` mounts the `ssl` directory into the nginx container:

```yaml
    volumes:
      - ./ssl:/etc/nginx/ssl:ro
```

4. The nginx config expects these files at `/etc/nginx/ssl/tls.crt` and `/etc/nginx/ssl/tls.key`.

5. Restart the nginx service:

```bash
docker compose restart nginx
```

6. Access the API securely:

```
curl -k https://localhost:6385/v1
```

#### Using Production Certificates

- Obtain a certificate and key from a trusted CA (e.g., Let's Encrypt, commercial CA).
- Place the certificate and key as `ssl/tls.crt` and `ssl/tls.key` in your project directory (or update the nginx config to match your filenames).
- Restart the nginx service as above.
- Remove or replace the self-signed files.

#### HTTP to HTTPS Redirect

- The nginx config includes a server block that redirects HTTP (port 80) requests to HTTPS (port 6385).
- Always use `https://` for API access in production.

## AI Disclosure

This repo was developed with the assistance of GitHub Copilot.
