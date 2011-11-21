
Quick provision script snap-guest for QEMU/KVM
==============================================

Snap-guest is a simple script for creating copy-on-write QEMU/KVM guests.

Features
--------

 * creates qcow2 image based on different one
 * generates MAC address out of hostname
 * modifies network settings (MAC, hostname) for Fedora/Red Hat distros
 * creates and provisions guest using virt-install
 * nice cli interface

Requirements
------------

 * bash :-)
 * sed
 * python-virtinst
 * qemu-img
 * libguestfs-mount
 * vim (no, you don't really need it, but it's recommended :-)

How it works
------------

First of all you need to create base image using any method you want (e.g. 
virt-manager). It's recommended to use "base" string in the guest name
(e.g. fedora-10-base or rhel4-base). The template image format can be qcow2 as 
well as different one (raw on LVM for example).

Feel free to configure the base image according needs. It's recommended to 
install few packages like ntpd or acpid. The following blogpost contains more
information regarding configuring base (or "template") guest:

http://lukas.zapletalovi.com/2011/08/configure-red-hat-or-fedora-as-guest.html

The only requirement is the hostname - it must be same as the base guest name.
So if you name the VM fedora-10-base, hostname must be set the same.

The usage is very easy then:

    usage: ./snap-guest options

    Simple script for creating copy-on-write QEMU/KVM guests.

    OPTIONS:
      -h             Show this message
      -l             List avaiable images (with "base" in the name)
      -a             List all images
      -b [image]     Base image name (template) - required
      -t [image]     Target image name (and hostname) - required
      -n [network]   Network settings (default: "network=default")
      -m [MB]        Memory (default: 800 MiB)
      -c [CPUs]      Number of CPUs (default: 1)
      -p [path]      Images path (default: /var/lib/libvirt/images/)
      -d [domain]    Domain suffix like "mycompany.com" (default: none)
      -f             Force creating new guest (no questions)

    EXAMPLE:

      ./snap-guest -l
      ./snap-guest fedora-17-base test-vm
      ./snap-guest fedora-17-base test-vm2 -n bridge=br0 -d example.com
      ./snap-guest rhel-6-base test-vm -m 2048 -c 4 -p /mnt/data/images

Snap-guest is a great tool for developing or testing. Provisioning new guest 
from a template is very fast (about 5-10 seconds).

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
assign it the very same IP address.

Credits and license
-------------------

The script is distributed under public domain.

Original script was written by Red Hat folks (Jason Dobies, Shannon Hughes,
Mike McCune and others), I have slightly modified it, I was using it and after 
few improvements I decided to share it with the world.

vim: tw=79:fo+=w
