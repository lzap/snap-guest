Quick provision script snap-guest for QEMU/KVM
==============================================

Snap-guest is a simple script for creating copy-on-write QEMU/KVM guests.

Fedora KVM instance booted into working shell in 2 seconds? No containers 
involved, no magic.

Upstream site is at http://github.com/lzap/snap-guest

Features
--------

 * easy-to-learn CLI
 * creates qcow2 image based on different one
 * creates and provisions guest using virt-install

Traditional image manipulation features:

 * generates MAC address out of hostname (more bellow)
 * modifies network settings (MAC, hostname) for Fedora/Red Hat distros
 * disables fsck check during boot

Cloud image-based provisioning features:

 * generate simple meta-data (uuid = hostname)
 * generate trivial user-data (enable root login, use user's RSA public key)
 * allows user to pass own user-data

Installation
------------

Dependencies for RHEL6/Fedora:

 * yum -y install bash sed python-virtinst qemu-img libguestfs-mount \
    perl perl-Sys-Guestfs kvm cloud-utils openssl util-linux genisoimage

And then:

 * git clone git://github.com/lzap/snap-guest.git
 * sudo ln -s $PWD/snap-guest/snap-guest /usr/local/bin/snap-guest

There are two ways of using snap-guest: traditional image manipulation and 
cloud image based snapping.

Traditional image manipulation
------------------------------

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

      ./snap-guest --list
      ./snap-guest -p /mnt/data/images --list-all
      ./snap-guest -b fedora-17-base -t test-vm -s 4098
      ./snap-guest -b fedora-17-base -t test-vm2 -n bridge=br0 -d example.com
      ./snap-guest -b rhel-6-base -t test-vm -m 2048 -c 4 -p /mnt/data/images

Cloud image based snapping
--------------------------

Don't want to bother preparing base images? Why not to leverage one of these 
which are already there! http://openstack.redhat.com/Image_resources

Have a working Fedora instance in three simple steps:

    # wget http://cloud.fedoraproject.org/fedora-19.x86_64.qcow2 \
        -O /var/lib/libvirt/images/f19-base.img
    # snap-guest -b f19 -t myguest --cloud-image --user-data-ssh
    # ssh fedora@192.168.122.123

Do you like that? Snap that again, now maybe with custom user data and bridged 
networking and full hostname with domain. If you don't know cloud-init syntax, 
read this: https://help.ubuntu.com/community/CloudInit

    # snap-guest -b f19 -t myguest --cloud-image --user-data-file my_app.yaml \
        --network bridge=br0 --domain xxx.redhat.com --force

Note that you don't need to delete the running host. The --force option will 
destroy and undefine previous guest automatically.

Now you want to move snap-guest to a server and snap instances from your 
laptop. Not a problem!
    
    # cat my_app.yaml | ssh root@dev-server "snap-guest -b f19 -t myguest \
        --cloud-image --user-data-stdin -n bridge=br0 -d xxx.redhat.com -f"

And now you want more complex scenario - you want to install things on that 
instance during start. With cloud-utils tool, you can create multipart user 
data with bash scripts and other things.

    # write-mime-multipart --output=combined-my_app.yaml \
        install_software.sh:text/x-shellscript \
        my_app.yaml
    # cat my_app.yaml | ssh root@dev-server "snap-guest -b f19 ..."

Of course you can directly pipe the former command into the latter, but we 
leave this as an exercise.

We ship some example scripts, for example you can install The Foreman 
application (http://www.theforeman.org) using the following command:

    # vim apps/example.yaml (put your ssh key and review settings)
    # write-mime-multipart apps/foreman/dev:text/x-shellscript \
    apps/example.yaml | ssh root@dev-server "snap-guest -b f19 ..."

Usage
-----

Here you can find all parameters:

    usage: ./snap-guest options

    Tool for ultra-fast copy-on-write image provisioning. Prepare a base image (or
    download a cloud image) and then spawn an COW instance. Then again, and again.

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
            For cloud-image provisioning swap is not turned on automatically and
            you need to do this manually in user-data script (swapon /dev/vdb).
      --firstboot [command] | -1 [command]
            Command to execute during first boot in /root dir
            (logfile available in /root/firstboot.log)
      --cloud-image
            Disables image manipulation and enables cloud-init seed via CD-ROM
      --user-data-file [file]
            Reads cloud-init user-data from file
      --user-data-ssh
            Generate primitive user-data file with only your public ssh key
      --user-data-stdin
            Reads cloud-init user-data from standard input
            (overrides all --user-data-* options)

Warning
-------

There is one **important thing** you need to know. Once you have some guests, 
you **must not start** template (base) image, because that would break the 
"child" guests.

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

It is also possible to provision guests with static network settings. It is 
currently available for Fedora and Red Hats. Example options:

    snap-guest ... \
        --static-ipaddr 192.168.100.2 \
        --static-netmask 255.255.255.0 \
        --static-gateway 192.168.100.1

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

So
--

Snap-guest is a great tool for developing or testing. It's simple and fast.

Credits and license
-------------------

The script is distributed as public domain.

Original script was written by Red Hat folks (Jason Dobies, Shannon Hughes,
Mike McCune and others), I have slightly modified it, I was using it and after 
few improvements I decided to share it with the world.

Special thanks to all who improve this set of scripts. See AUTHORS for full 
list.

vim: tw=79:fo+=w
