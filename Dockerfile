FROM python:3.12

WORKDIR /app

EXPOSE 6385 8080

RUN apt-get update && apt-get install -y jq \
	isolinux \
	syslinux-utils \
	xorriso \
	genisoimage \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/lib/syslinux && \
	ln -sf /usr/lib/ISOLINUX/isolinux.bin /usr/lib/syslinux/isolinux.bin || true

# Preconfigure the in-container Ironic CLI (python-ironicclient) to talk to
# the local API without Keystone (noauth).
ENV OS_AUTH_TYPE=none \
	OS_ENDPOINT=http://127.0.0.1:6385

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Entrypoint that initializes the DB on first run and skips if existing
COPY entrypoint.sh /usr/local/bin/ironic-entrypoint
RUN chmod +x /usr/local/bin/ironic-entrypoint

# Use our entrypoint to manage DB and start API+conductor (AIO)
ENTRYPOINT [ "/usr/local/bin/ironic-entrypoint" ]
CMD []
