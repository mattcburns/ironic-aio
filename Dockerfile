# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
FROM python:3.12

ARG TARGETARCH

WORKDIR /app

EXPOSE 6385

# syslinux-utils (isohybrid) is not packaged for arm64 on Debian
RUN apt-get update && \
	pkgs="jq isolinux xorriso genisoimage" && \
	if [ "$TARGETARCH" = "amd64" ]; then pkgs="$pkgs syslinux-utils"; fi && \
	apt-get install -y $pkgs && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/lib/syslinux && \
	ln -sf /usr/lib/ISOLINUX/isolinux.bin /usr/lib/syslinux/isolinux.bin || true

# Preconfigure the in-container Ironic CLI (python-ironicclient) to talk to
# the local API without Keystone (noauth).
ENV OS_AUTH_TYPE=none \
	OS_ENDPOINT=http://127.0.0.1:6385

# Install dependencies
COPY requirements.txt .
COPY upper-constraints.txt .
# upper-constraints for master for now since 2026.1 hasn't been released yet
RUN pip install --no-cache-dir -r requirements.txt -c upper-constraints.txt
# RUN pip install --no-cache-dir -r requirements.txt -c https://raw.githubusercontent.com/openstack/requirements/refs/heads/2025.2/upper-constraints.txt

# Entrypoint that initializes the DB on first run and skips if existing
COPY entrypoint.sh /usr/local/bin/ironic-entrypoint
RUN chmod +x /usr/local/bin/ironic-entrypoint

# Use our entrypoint to manage DB and start API+conductor (AIO)
ENTRYPOINT [ "/usr/local/bin/ironic-entrypoint" ]
CMD []
