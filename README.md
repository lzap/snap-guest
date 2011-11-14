
Quick provision script snap-guest for QEMU/KVM
==============================================

Snap-guest is a simple script for creating copy-on-write QEMU/KVM guests.

Features
--------

 * creates qcow2 image based on different one
 * generates MAC address out of hostname
 * modifies network settings (MAC, hostname) for Fedora/Red Hat distros
 * creates and provisions guest using virt-install

How it works
------------

First of all you need to create base image using any method you want (e.g. 
virt-manager). It's recommended to use "base" string in the guest name
(e.g. fedora-10-base or rhel4-base).

Feel free to configure the base image according needs. It's recommended to 
install few packages like ntpd or acpid. The following blogpost contains more
information regarding configuring base (or "template") guest:

http://lukas.zapletalovi.com/2011/08/configure-red-hat-or-fedora-as-guest.html

The only requirement is the hostname - it must be same as the base guest name.
So if you name the VM fedora-10-base, hostname must be set the same.

The usage is very easy then:

    Usage: BASE_IMAGE TARGET_IMAGE [MEMORY IN MB] [NO OF CPUS] [NETWORK OPTIONS]

Examples
--------

    /usr/local/bin/snap-guest fedora-15-base test 1024 2 network=default

    /usr/local/bin/snap-guest fedora-16-base sixteen 512 1 bridge=eth0

Snap-guest is a great tool for developing or testing. Provisioning new guest from
a template is very fast (about 5-10 seconds).

Network
-------

The script modifies network settings in /etc/sysconfig directory (hostname and MAC 
address of the eth0). The MAC address is generated based on the hostname - the same
hostname always gives the same address. Example:

    hostname a => mac 52:54:00:60:b7:25
    hostname b => mac 52:54:00:3b:5d:5c
    hostname a => mac 52:54:00:60:b7:25 (the same)

This is great for testing - when you provision a box called let's say "test" and
delete it, once it is provisioned again with the same name, DHCP will assign
it the very same IP address.

Credits and license
-------------------

The script is distributed under public domain.

Original script was written by Red Hat folks, I have slightly modified it, I
was using it and after few improvements I decided to share it with the world.

