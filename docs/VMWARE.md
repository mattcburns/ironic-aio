# VMWare Installer Support

## TLDR:

- VMWare ISO should be extracted and customized as desired and then repackaged
  as an ISO.
- Kickstart file either needs to be packaged into the provided ISO or the
  boot.cfg file packaged into the ISO needs to point to a kickstart file.
- That ISO is provided to Ironic via a HTTP accessible endpoint that the BMC can
  reach.
- Networking for the ISO either needs to be provided by a kickstart (ks.cfg)
  file added to the custom ISO or provided by an external DHCP service (when
  necessary to provision the node.)

## Introduction

VMWare ESX/ESXi/VCenter/etc can be network booted but cannot be imaged in the
traditional way that Ironic expects. We can get around that by using the ramdisk
deployment driver which requires only an ISO to provision and some network
configuration (more on this later.)

## Networking

VMWare automates installation using a kickstart (ks.cfg) file. This file is
either provided on the ISO image or hosted on a web server somewhere. The boot
configuration is set to where the kickstart can be found. In the case of a
remotely hosted kickstart file, DHCP will need to be provided to the server on
boot (outside the scope of Ironic.) Otherwise, if the kickstart is already
bundled into the ISO, networking can be configured there.

## Booting the VMWare ISO

1. Download and extract the appropriate VMWare installation ISO from the
  Broadcom support downloads website.
1. Perform the appropriate customizations to the extracted files. This can
  include any DIBs, boot.cfg and ks.cfg configuration changes.
1. Repackage the installation directory as an ISO:

    ```bash
    xorriso -as mkisofs \
      -relaxed-filenames \
      -J -R \
      -o vmware9.iso \
      extracted-esxi/
    ```

1. Make sure the node is set to use the ramdisk deploy driver:

    ```bash
    docker compose exec ironic baremetal node set <node_id> --deploy-interface ramdisk
    ```

1. Configure the boot iso on the node:

    ```bash
    docker compose exec ironic baremetal node set <node_id> --instance-info boot_iso=http://192.168.0.100:8080/vmware/vmware9.iso
    ```

1. Deploy the node

    ```bash
    docker compose exec ironic baremetal node deploy <node_id>
    ```
