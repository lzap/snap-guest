yum -y install http://yum.theforeman.org/releases/1.2/el6/x86_64/foreman-release.rpm
yum -y install foreman-installer
echo include foreman_installer | puppet apply -v --modulepath /usr/share/foreman-installer
