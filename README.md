# Quick provision script snap-guest for QEMU/KVM

Snap-guest is a simple script for creating copy-on-write QEMU/KVM guests.

## Features

Before you start, you need to have a base qcow2 image customized to your needs
(updated, passwords set, SSH keys, sofware installed). The README will describe
how to easily do this with `virt-install`.

 * CLI
 * creates a derived qcow2 image
 * starts a VM using virt-install

Traditional image manipulation features:

 * generates MAC address out of hostname for consistent IP
 * modifies network settings (MAC, hostname) for Fedora/Red Hat distros
 * disables fsck check during boot

## Installation

Dependencies for Red Hat systems:

 * dnf -y install bash sed python-virtinst qemu-img libguestfs-mount \
    perl perl-Sys-Guestfs kvm openssl util-linux

And then:

 * git clone https://github.com/lzap/snap-guest
 * sudo ln -s $PWD/snap-guest/snap-guest /usr/local/bin/snap-guest

## Base image creation

Before you can do anything, a base image must exist. It's recommended to use
"base" string in the guest name (e.g. fedora-10-base or rhel4-base) to
differentiate those files (snap-guest lists them using -l option), but it is
not mandatory (option -a lists them all). The base image does not have to be
qcow2! You can use RAW image as well, however, testing showed that there is no
measurable benefit from using RAW images, especially when using `unsafe`.

The only requirement is the *hostname* - it must be same as the base guest name.
So if you name the VM fedora-10-base, hostname must be set the same without any
domain.

To create a base image, use `virt-builder` which can download and preare wide
variety of OS images (Fedora, CentOS, Debian, Ubuntu). It creates either
uncompressed qcow2 images or (sparse) RAW images. Since for snap-guest,
compressed qcow2 makes a lot of sense, create intermediate RAW image first:

# centosstream-9

    OS=rhel-9.8
    virt-builder "$OS" \
        --output "/scratch/images/$OS-base.raw" \
        --format raw \
        --size "100G" \
        --root-password password:redhat \
        --run-command 'useradd -m lzap' \
        --ssh-inject "root:file:$HOME/.ssh/id_ed25519.pub" \
        --ssh-inject "lzap:file:$HOME/.ssh/id_ed25519.pub" \
        --hostname "$OS-base" \
        --update \
        --install vim

Note the image size is 100GB, but thanks to spare support in Linux, the image
will actually take just few hundreds MBs. Now, convert it to compressed qcow2:

    qemu-img convert -c -O qcow2 -o compression_type=zstd \
        "/scratch/images/$OS-base.raw" \
        "/scratch/images/$OS-base.qcow2" && \
        rm "/scratch/images/$OS-base.raw"

Note for Red Hat associates: You can configure `virt-builder` with internal
repository which carries all RHEL versions available to date.

Usage
-----

The usage is very easy then:

      ./snap-guest --list
      ./snap-guest -p /scratch/images --list-all
      ./snap-guest -b fedora-17-base -t test-vm -s 4098
      ./snap-guest -b fedora-17-base -t test-vm2 -n bridge=br0 -d example.com
      ./snap-guest -b rhel-6-base -t test-vm -m 2048 -c 4 -p /mnt/data/images

Here you can find all parameters:

    usage: ./snap-guest options

    Tool for ultra-fast copy-on-write image provisioning. Prepare a base image and
    then spawn a COW instance. Then again, and again.

    OPTIONS:
      --help | -h
            Show this message
      --list | -l
            List avaiable images (with "base" in the name)
      --list-all
            List all images
      --base [image] | -b [image]
            Base image name (template) - required
      --target [name] | -t [name]
            Target image name (and hostname) - required
      --network [opts] | -n [opts]
            Network options for virt-install (default: "network=default")
      --network2 [opts]
            Second network NIC settings (none by default)
      --memory [MB] | -m [MB]
            Memory (default: 800 MiB)
      --cpus [CPUs] | -c [CPUs]
            Number of CPUs (default: 1)
      --image-dir [path] | -p [path]
            Target images path (default: /var/lib/libvirt/images/)
      --base-image-dir [path]
            Base images path (default: /var/lib/libvirt/images/)
      --domain [domain] | -d [domain]
            Domain suffix like "mycompany.com" (default: none)
      --domain-prefix [prefix]
            Domain prefix like "test-" -> "test-NAME.lan" (default: none)
      --force | -f
            Force creating new guest (no questions, destroys one the same name)
      --add-ip | -w
            Add IP address to /etc/hosts (works only with NAT)
      --graphics [opts] | -g [opts]
            Graphics options passed to virt-install via --graphics
            (default is vnc,listen=0.0.0.0)
      --swap [MBs] | -s [MBs]
            Creates RAW disk and connects and mounts it of given size (in MB)
            Note the virtual disc has no parititions.
      --firstboot [command] | -1 [command]
            Command to execute during first boot in /root dir
            (logfile available in /root/firstboot.log)

## Do not start base images

There is one **important thing** you need to know. Once you have some guests,
you **must not start** template (base) image, because that would break the
"child" guests.

Network
-------

The script modifies network settings in /etc/sysconfig directory (hostname and
MAC address of the eth0). The MAC address is generated based on the hostname -
the same hostname always gives the same address. Example:

    hostname a => mac 52:54:00:60:b7:25
    hostname b => mac 52:54:00:3b:5d:5c
    hostname a => mac 52:54:00:60:b7:25 (the same)

This is great for testing - when you provision a box called let's say "test"
and delete it, once it is provisioned again with the same name, DHCP will
assign it the very same IP address. You can keep hostnames and IPs in the
/etc/hosts file and if you won't be shut down your guests for longer periods,
IPs never change.

It is also possible to provision guests with static network settings. It is
currently available for Fedora and Red Hats. Example options:

    snap-guest ... \
        --static-ipaddr 192.168.100.2 \
        --static-netmask 255.255.255.0 \
        --static-gateway 192.168.100.1

Additionally, if you use snap-guest on the same host where KVM is running,
there is a flag that adds entries to your /etc/hosts automatically. See help
section for more details.

## Credits and license

The script is distributed as public domain.

Original script was written by Red Hat folks (Jason Dobies, Shannon Hughes,
Mike McCune and others).

Special thanks to all who improve this set of scripts. See AUTHORS for full
list.
