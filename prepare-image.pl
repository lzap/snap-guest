#!/usr/bin/perl

use strict;
use Sys::Guestfs;

my $g = Sys::Guestfs->new ();

# For debugging.
#$g->set_trace (1);

# Add the disk and launch.
$g->add_drive_opts ($ENV{TARGET_IMG}, format => "qcow2");
$g->launch ();

# Inspect for OSes.
my @roots = $g->inspect_os ();
die "no operating system was found" if @roots == 0;
die "dual/multi-boot operating system not supported" if @roots > 1;
my $root = $roots[0];

# Get OS and version.
my $type = $g->inspect_get_type ($root);
my $distro = $g->inspect_get_distro ($root);
my $major = $g->inspect_get_major_version ($root);
my $minor = $g->inspect_get_minor_version ($root);

print "OS: $type $distro $major $minor\n";

# Mount up the operating system disks.
my %mps = $g->inspect_get_mountpoints ($root);
my @mps = sort { length $a <=> length $b } (keys %mps);
for my $mp (@mps) {
  eval { $g->mount ($mps{$mp}, $mp) }
}

print "Disable fsck startup check for all volumes\n";
my $file;
my $content;
$file = "/etc/fstab";
$content = $g->read_file ($file);
$content =~ s/[0-9]$/0/g;
$g->write ($file, $content);

print "Configuring message of the day\n";
$content = "\n\nSnap-guest box from $ENV{BASE_IMAGE_DIR} on " . `date` . "\n\n";
$g->write ("/etc/motd", $content);

print "Configuring /etc/hosts file\n";
$file = "/etc/hosts";
$content = $g->read_file ($file);
$content =~ s/$ENV{SOURCE_NAME}/localbox/g;
$content .= "\n127.0.0.1 $ENV{TARGET_HOSTNAME} $ENV{TARGET_NAME}\n";
$g->write ($file, $content);

if ($distro eq "debian" || $distro eq "ubuntu") {
  print "Setting up for Debian\n";
  # nothing
}
elsif ($distro =~ m/^(fedora|rhel|redhat-based|centos|scientificlinux)$/) {
  print "Setting up for Fedora / RHEL\n";
  print "Setting MAC address\n";
  $file = "/etc/sysconfig/network-scripts/ifcfg-eth0";
  $content = $g->read_file ($file);
  $content =~ s/HWADDR=.*/HWADDR=$ENV{MAC}/g;
  $g->write ($file, $content);

  print "Setting hostname\n";
  if ($major >= 18) {
    $g->write ("/etc/hostname", $ENV{TARGET_HOSTNAME});
  } else {
    $file = "/etc/sysconfig/network";
    my @lines = $g->read_lines ($file);
    my $found_it = 0;
    foreach (@lines) {
      s/HOSTNAME=.*/HOSTNAME=$ENV{TARGET_HOSTNAME}/;
      $found_it = 1;
    }
    if (!$found_it) {
      push @lines, "# added by snap-guest", "HOSTNAME=$ENV{TARGET_HOSTNAME}";
    }
    $g->write ($file, join ("\n", @lines) . "\n");
  }
}

if ($ENV{SWAP}) {
  print "Adding swap file\n";
  $file = "/etc/fstab";
  $content = $g->read_file ($file);
  $content .= "\n/dev/vdb none swap swap 0 0\n";
  $g->write ($file, $content);
}

if ($ENV{COMMAND}) {
  print "Preparing fristboot command and tt watch progress alias\n";
  $content = "pushd /root\n$ENV{COMMAND}\npopd\n";
  $g->write ("/root/firstboot.sh", $content);

  $file = "/etc/rc.d/rc.local";
  if ($g->exists ($file)) {
    $content = $g->read_file ($file);
  } else {
    $content = "#!/bin/bash\n";
  }
  $content .= "\nbash -x /root/firstboot.sh 2>&1 | /usr/bin/tee /root/firstboot.log\n";
  $g->write ($file, $content);
  $g->chmod (0755, $file);

  $file = "/root/.bashrc";
  if ($g->exists ($file)) {
    $content = $g->read_file ($file);
  } else {
    $content = "";
  }
  $content .= "\n# snap-guest\nalias tt=\"tail -f -n500 /root/firstboot.log\"\n\n";
  $g->write ($file, $content);
}

# Shutdown the appliance cleanly.
$g->umount_all ();
$g->shutdown ();
$g->close ();
