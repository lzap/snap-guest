Quick provision script snap-guest for QEMU/KVM
==============================================

Snap-guest is a simple script for creating copy-on-write QEMU/KVM guests.

Upstream site is at http://github.com/lzap/snap-guest

Features
--------

 * creates qcow2 image based on different one
 * generates MAC address out of hostname
 * modifies network settings (MAC, hostname) for Fedora/Red Hat distros
 * disables fsck check during boot (qcow2 images can have lost inodes)
 * creates and provisions guest using virt-install
 * nice cli interface

Requirements
------------

This is for RHEL6/Fedora:

    yum -y install sed python-virtinst qemu-img libguestfs-mount perl-Sys-Guestfs

Installation
------------

 * yum -y install bash sed python-virtinst qemu-img libguestfs-mount
 * git clone git://github.com/lzap/snap-guest.git
 * sudo ln -s $PWD/snap-guest/snap-guest /usr/local/bin/snap-guest

How it works
------------

First of all you need to create base image using any method you want (e.g. 
virt-manager). It's recommended to use "base" string in the guest name
(e.g. fedora-10-base or rhel4-base) to differentiate those files (snap-guest
lists them using -l option), but it is not mandatory (option -a lists them 
all). The template image format can be qcow2 as well as different one (raw on 
LVM for example).

Feel free to configure the base image according to your needs. It's recommended
to install a few packages like ntpd or acpid. Make sure network is also on when
switching off NetworkManager. The following blog post contains more information 
about configuring base (or "template") guest:

http://lukas.zapletalovi.com/2011/08/configure-red-hat-or-fedora-as-guest.html

I also recommend to configure serial console for both terminal and grub. There
is a simple way to do that, for example for Fedora you need to do this:

    cat >> /etc/default/grub <<'EOF'
    GRUB_TIMEOUT=1
    GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX text console=tty0 console=ttyS0,115200n8"
    GRUB_TERMINAL=serial
    GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"
    EOF
    grub2-mkconfig -o /boot/grub2/grub.cfg

Then it is possible to connect to the console with:

    virsh console guestname

There is a gist with several other extra commands from the above blog post:
https://gist.github.com/lzap/4984838

To use it do this:

    # \curl -L https://gist.github.com/lzap/4984838/raw | bash -xs

*Important note*

The only requirement is the *hostname* - it must be same as the base guest name.
So if you name the VM fedora-10-base, hostname must be set the same.

The usage is very easy then:

    usage: ./snap-guest options

    Simple script for creating copy-on-write QEMU/KVM guests. For the base image
    install Fedora or RHEL (compatible), install acpid and ntpd or similar, do not
    make any swap partition (use -s option), make sure the hostname is the same
    as the vm name and it has "base" in it. Example: rhel-6-base.

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
      -w             Add IP address to /etc/hosts (works only with NAT)
      -s             Swap size (in MB) that is appeded as /dev/sdb to fstab
      -1 [command]   Command to execute during first boot in /root dir
                     (logfile available in /root/firstboot.log)

    EXAMPLE:

      ./snap-guest -l
      ./snap-guest -p /mnt/data/images -l
      ./snap-guest -b fedora-17-base -t test-vm -s 4098
      ./snap-guest -b fedora-17-base -t test-vm2 -n bridge=br0 -d example.com
      ./snap-guest -b rhel-6-base -t test-vm -m 2048 -c 4 -p /mnt/data/images

Snap-guest is a great tool for developing or testing. Provisioning a new
guest  from a template is very fast (about 5-10 seconds).

Warning
-------

There is one **important thing** you need to know. Once you have some guests, 
you **must not start** a template image, because that would break the "child" 
guests.

You also **must not** change a template even when the "child" guests are 
_not_ running. Again, if anything changes in a template, images based on the 
template will be corrupted. Sooner or later.

Trust me, it can seem to work since there is lot of files in a modern 
distribution (even a minimal installation). But the probability you corrupt 
some important files is very high. The template must not change when there are 
"child" guests - never ever.

The only safe way to change something in a template is to **destroy** all the 
"child" guests, change it and then re-provision them again. It's not big deal - 
it is fast, you know.

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

Additionally, if you use snap-guest on the same host where KVM is running, 
there is a flag that adds entries to your /etc/hosts automatically. See help 
section for more details.

Recommended disk layout
-----------------------

Since snap-guest does not support LVM, you have to rely on the formatted 
partition. It is recommended to use separate dedicated partition for 
snap-guest. I am happy with ext4 using the extent option enabled and a
bigger block size. Something like:

    # pvdisplay
    # lvdisplay
    # lvcreate -L 140G -n lv_images vg_myhost
    # mkfs.ext4 -b 4096 -O extent /dev/mapper/vg_myhost-lv_images

Credits and license
-------------------

The script is distributed as public domain.

Original script was written by Red Hat folks (Jason Dobies, Shannon Hughes,
Mike McCune and others), I have slightly modified it, I was using it and after 
few improvements I decided to share it with the world.

Special thanks to all who improve this set of scripts. See AUTHORS for full 
list.

vim: tw=79:fo+=w
