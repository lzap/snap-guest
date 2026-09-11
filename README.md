# snap-guest

`snap-guest` creates a qcow2 overlay and runs it through the unprivileged
`qemu:///session` libvirt connection. It uses rootless `passt` user-mode
networking and forwards deterministic TCP ports to the guest.

After the guest is reachable, the tool sets the target hostname over SSH,
reboots the guest, and waits until SSH is available again. Thanks to DHCP/DNS
integration in libvirt the host is accessible via DNS.  It never mounts or
modifies the base image.

By default, snap-guest forwards guest TCP ports `22`, `80`, `443`, and `3000`.
Use `--ports` to provide a comma-separated replacement list. Each host port is
derived from the KVM host name, target name, and guest port, so it is stable for
that target on the same host. By default, forwards listen only on `127.0.0.1`.
Use `--bind-all` to expose them on all host addresses; the output then uses the
target name in the URLs. Configure that name in DNS to resolve to the KVM host.

When provisioning finishes, snap-guest maintains its host aliases in
`~/.ssh/config-snap-guest`. To use those aliases, add this line to your SSH
configuration yourself:

    Include ~/.ssh/config-snap-guest

Thus the target can be used directly with SSH, without remembering its
forwarded port:

    ssh root@foreman.example.com

For a fully-qualified target such as `foreman.example.com`, both
`foreman` and `foreman.example.com` are available as SSH aliases. The user
selected with `--ssh-user` is configured for both aliases.

## Base-image contract

The base image must be a `.qcow2` file and must already contain:

* a running SSH server listening on port 22;
* the public SSH key of the user running `snap-guest`, or of the user supplied
  with `--ssh-user`;
* passwordless `sudo` for that user, unless it is `root`;
* `systemd` with `hostnamectl` and `systemctl` available.

The target name is also the hostname. A fully-qualified target name is allowed,
but rootless user-mode networking does not provide shared guest DNS.

## Installation

On Red Hat systems:

    dnf install bash coreutils libguestfs-tools openssh-clients openssl passt \
        qemu-img python-virtinst

By default, snap-guest reads and creates images in the user-session libvirt
image directory:

    ~/.local/share/libvirt/images

Run the script directly, or add a user-local symlink to your PATH:

    mkdir -p ~/.local/bin
    ln -s "$PWD/snap-guest" ~/.local/bin/snap-guest

## Base image creation

Create a base image for your chosen distribution, then convert it to qcow2.
Configure an SSH account, its authorized key, and passwordless sudo as part of
the image build. This generic example uses a `testuser` account:

    OS=your-os
    IMAGE_DIR="$HOME/.local/share/libvirt/images"
    SSH_USER=testuser
    mkdir -p "$IMAGE_DIR"
    virt-builder "$OS" \
        --output "$IMAGE_DIR/$OS-base.raw" \
        --format raw \
        --size 100G \
        --run-command "useradd -m $SSH_USER" \
        --run-command "echo '$SSH_USER ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/$SSH_USER" \
        --run-command "chmod 0440 /etc/sudoers.d/$SSH_USER" \
        --ssh-inject "$SSH_USER:file:$HOME/.ssh/id_ed25519.pub" \
        --hostname "$OS-base"

    qemu-img convert -c -O qcow2 -o compression_type=zstd \
        "$IMAGE_DIR/$OS-base.raw" \
        "$IMAGE_DIR/$OS-base.qcow2"

To list supported OSes:

    virt-builder --list

The base image can be also installed by regular OS installation, just make sure
to use qcow2 backend.

## Usage

    snap-guest --list
    snap-guest -b your-os-base -t foreman.example.com --ssh-user testuser
    snap-guest -b your-os-base -t satellite.example.com --ssh-user root
    snap-guest -b your-os-base -t web-test --ports 22,80,443,3000
    snap-guest -b your-os-base -t web-test --bind-all

The tool prints every forwarded port when the guest is ready, including clickable
HTTP and HTTPS URLs. The same summary is written to the guest MOTD:

    This VM was built with snap-guest.
    SSH: ssh testuser@foreman.example.com
    Forwarded ports on 127.0.0.1:
      127.0.0.1:PORT -> guest:22
      http://127.0.0.1:PORT/
      https://127.0.0.1:PORT/

Each host port is derived from the KVM host, target name, and guest port, so
recreating the same target uses the same MAC address and forwarding ports. Run
`snap-guest --help` for all options. Use `--force` to stop and undefine an
existing user-session domain of the target name and remove its target overlay
before creating a fresh test VM.

The `--unsafe` option enables unsafe disk caching and is intended only for
development and testing. It may ignore flush requests from the guest and can
cause data loss if the host fails.

## Credits and license

This project is distributed as public domain.

The original script was written by Red Hat folks, including Jason Dobies,
Shannon Hughes, Mike McCune, and others. See [AUTHORS](AUTHORS) for the full
list of contributors.

In 2026, snap-guest was completely revamped: cloud-init support was removed,
guest images are no longer mounted or modified, and the tool runs entirely
through unprivileged `qemu:///session` libvirt. Provisioning is done by SSH.
Host root privileges are no longer required.
