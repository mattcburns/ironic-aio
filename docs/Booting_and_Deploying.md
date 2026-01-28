# Booting and Deploying

For this distribution of Ironic we have one method to boot machines and two
methods to perform deployments. Which combinations you use depend on the
operating system and environment you want to deploy to. No matter what, all
methods require a Redfish endpoint and HTTP server.

## Deployment Interfaces

Deployment interfaces describe and control how the operating system is installed
onto the server.

### direct

Direct deployment requires booting to the IPA (Ironic Python Agent) and then
writing the operating system image to disk. Typically you use cloud images that
are built in qcow2 format.

### ramdisk

Ramdisk deployment is for booting an immutable live image (and ISO) that then
handles the operating installation (or is just for live use.) Ironic doesn't
control any actions once the server has been directed to boot from the ramdisk.
This type of boot is typically used for installing operating systems like
VMWare.

## Boot Interfaces

Boot interfaces describe and control how the server is booted to live images.

### redfish-virtual-media

This boot interface uses the virtual media connection provided by the BMC to
boot the server with the specified image. Generally, most servers built within
the last decade or so have BMCs that support virtual media support, assuming
the appropriate BMC license has been applied.

Ramdisk based deployment simply attaches the specified ISO and boots the machine.

When booting with the direct deployment method, the kernel, initramfs and esp
image are combined on the fly by Ironic to create the boot iso. This iso is then
mounted to the remote media endpoint. Metadata stored on the node is provided as
a config drive to enable network configuration on boot.

All of the commands below assume using the docker container for the baremetal
cli and assumes that `docker compose exec ironic` is pre-pended for all operations.

1. Enroll the node by creating it in the API: `baremetal node create --driver redfish --driver-info redfish_address=<redfish https endpoint> --driver-info redfish_username=<bmc user> --driver-info redfish_password=<bmc password> --driver-info redfish_verify_ca=False`
1. Make the node manageable: `baremetal node manage <node id>`
1. Apply the network data for cleaning: `baremetal node set --network-data /app/servers/<server>/network_data.json <node id>`
1. Make the node available for provisioning and trigger a cleaning: `baremetal node provide <node id>`
1. Configure the OS to provision: `baremetal node set <node id> --instance-info image_source=<url to os image> --instance-info image_checksum=<os image sha256sum>`
1. Provision the node: `baremetal node deploy <node id> --configdrive <some cloudinit json, optional>`
