echo "test"

read -p "Enter the Hostonly IP " hostip
sed -i "s/hostonlyip/$hostip/g" dhcp.cf

read -p "ENter the Start range of the ip : " stip
sed -i "s/start_ip/$stip/g" dhcp.cf

read -p "enter the End range of the ip : " endip
sed -i "s/endip/$endip/g" dhcp.cf

read -p "Enter the Gateway ip : " gatewayip
sed -i "s/gatewayip/$gatewayip/g" dhcp.cf

read -p "network : " ip_network
read -p "network mask : " network_mask

sed -i "s/ip_network/$ip_network/g" dhcp.cf
sed -i "s/network_mask/$network_mask/g" dhcp.cf

read -p "Enter the Broadcast IP : " broadcastip
sed -i "s/broadcastip/$broadcastip/g" dhcp.cf






