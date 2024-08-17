

echo "iNSTALLAION "

sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*

sed -i 's/#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*


cc(){
if [ $? -ne 0 ];then
echo "Failed the command !!!!"
exit
else
 echo "	#########	DONE - WORKING 	##########"
fi
}

yum install syslinux
cc
yum install xinetd
cc
yum install tftp-server
cc
yum install dhcp
cc
mkdir -p /var/lib/tftpboot/pxelinux.cfg
cc

cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
cc
cc
cp tftp.cf /etc/xinetd.d/tftp
cc

systemctl start xinetd
cc
systemctl enable xinetd
cc

#cp dhcp.back dhcp.cf
cc

#bash -x dhcp.sh
cc

#cp dhcp.cf /etc/dhcp/dhcpd.conf
cc
#systemctl restart dhcpd
cc

mkdir -p /var/pxe/centos7 
cc
mkdir -p /var/lib/tftpboot/centos7/root
cc

#yum -y install dracut-network
cc
yum -y install nfs-utils 
cc
#yum groups -y install "Minimal Install" --releasever=7 --installroot=/var/lib/tftpboot/centos7/root/
cc
echo  "Enter the password for the root in client side..!!! "
bash password.sh
cc
mv /home/admin/Desktop/script-stateless/shadow.temp /var/lib/tftpboot/centos7/root/etc/shadow
cc
cp fstab.cfg /var/lib/tftpboot/centos7/root/etc/fstab
cc



read -p "ente rthe location of the iso file " loc_ISO
#mount -t iso9660 -o loop $loc_ISO  /var/pxe/centos7
cc

cp /var/pxe/centos7/images/pxeboot/vmlinuz /var/lib/tftpboot/centos7/
cc

cp /var/pxe/centos7/images/pxeboot/initrd.img /var/lib/tftpboot/centos7/ 
cc

cp /usr/share/syslinux/menu.c32 /var/lib/tftpboot/ 
cc
read -p "Enter the System ip " ipa
cc
echo $ipa
sed -i "s/sysip/$ipa/g" /home/admin/Desktop/script-stateless/default.menu
cc
cp /home/admin/Desktop/script-stateless/default.menu /var/lib/tftpboot/pxelinux.cfg/default
cc
echo "/var/lib/tftpboot/centos7/root $ip_add/24(rw,no_root_squash)" > /etc/exports

systemctl start rpcbind nfs-server
systemctl enable rpcbind nfs-server


#cp pxeboot.config /etc/httpd/conf.d/pxeboot.conf
cc
#systemctl restart httpd 





