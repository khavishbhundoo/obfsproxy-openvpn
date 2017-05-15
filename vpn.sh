#!/bin/bash
cat <<EOF
#########################################################################
#       Setup OpenVPN + Obfsproxy to bypass Advanced Firewall           # 
#       Bypass China, Syria , Iran and Pakistan Internet Censorship     #
#       Author : Khavish Anshudass Bhundoo                              #
#########################################################################      
EOF
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
#Checking swap
if [[ -n $(/sbin/swapon -s | grep -q /dev) ]]; then
    :
else
echo  "Creating 512MB of swap space as no swap space currently exist"
#Create and activate a 512MB swap file
{
    dd if=/dev/zero of=/swapfile1 bs=1024 count=524288
	mkswap /swapfile1
	chown $USER:$USER /swapfile1
	chmod 0600 /swapfile1
	swapon /swapfile1
	echo "/swapfile1 swap swap defaults 0 0" >> /etc/fstab
	swapoff -a
	swapon -a
} &> /dev/null
fi	
#
#Setting Home directory
HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
echo  "Setting Up EPEL  Repository"
{
yum -y -q install wget
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo rpm -Uvh epel-release-latest-7.noarch.rpm
#
} &> /dev/null
#Time to install and configure Yum Priorities
{
yum clean all
yum history new
yum -q -y install yum-priorities
sed  -e '/\[base\]/,/gpgcheck=1/{/gpgcheck=1/{a\priority=10' -e ':a;n;ba}}' /etc/yum.repos.d/CentOS-Base.repo
sed  -e '/\[updates\]/,/gpgcheck=1/{/gpgcheck=1/{a\priority=10' -e ':a;n;ba}}' /etc/yum.repos.d/CentOS-Base.repo
sed  -e '/\[updates\]/,/gpgcheck=1/{/gpgcheck=1/{a\priority=10' -e ':a;n;ba}}' /etc/yum.repos.d/CentOS-Base.repo
sed  -e '/\[extras\]/,/gpgcheck=1/{/gpgcheck=1/{a\priority=10' -e ':a;n;ba}}' /etc/yum.repos.d/CentOS-Base.repo
sed  -e '/\[centosplus\]/,/gpgcheck=1/{/gpgcheck=1/{a\priority=20' -e ':a;n;ba}}' /etc/yum.repos.d/CentOS-Base.repo
sed  -e '/\[epel\]/,/gpgcheck=1/{/gpgcheck=1/{a\priority=65' -e ':a;n;ba}}' /etc/yum.repos.d/epel.repo
#Updating system
echo "Updating System"; 
yum -y -q install yum-utils
package-cleanup --cleandupes > /dev/null
yum -y -q upgrade 
yum -y -q update
} &> /dev/null
echo "Server Softwares and Kernel Updated...." 
#Installing some commonly used tools
echo "Installing useful tools{nano , wget, make}"
{
yum -y -q install nano
yum -y -q install wget
yum -y -q install make 
} 2>&1 | grep -v "already installed and latest version"
echo "Installing OpenVPN"
{
yum -y -q install openvpn
systemctl start openvpn@server
systemctl -f enable openvpn@server.service
} &> /dev/null
echo "Installing obfsproxy"
{
yum install -y -q make automake gcc python-pip python-devel libyaml-devel
pip install --upgrade pip
pip install obfsproxy 
yum install -y -q screen
screen -d -m obfsproxy --log-file=obfsproxy.log --log-min-severity=info obfs3 --dest=127.0.0.1:443 server 0.0.0.0:21194 
echo "obfsproxy --log-file=obfsproxy.log --log-min-severity=info obfs3 --dest=127.0.0.1:443 server 0.0.0.0:21194" >> /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local
} &> /dev/null
#Downloading Easy RSA package to create keys and certificates
echo "Setting Up Keys and Certificates"
{
yum install -y -q easy-rsa
rsync -av /usr/share/easy-rsa/ /etc/openvpn/easy-rsa/
chown -R $USER /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa/2.0/
source vars
} &> /dev/null
./clean-all
./build-ca
./build-key-server server
./build-dh
./build-key client
{
cd /etc/openvpn/easy-rsa/2.0/keys
cp ca.crt ca.key dh2048.pem server.crt server.key /etc/openvpn
mkdir -p $HOME/client-files
cp ca.crt client.crt client.key $HOME/client-files
openvpn --genkey --secret /etc/openvpn/ta.key
cp /etc/openvpn/ta.key $HOME/client-files
} &> /dev/null
echo "Configuring OpenVPN with obfsproxy"
{
ipaddr=$(curl -s http://whatismyip.akamai.com/)
cat > $HOME/client-files/scrambled-client.ovpn <<EOL
client
dev tun
proto tcp #for obfsproxy, otherwise udp
remote ${ipaddr} 21194
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
cert client.crt
key client.key
tls-auth ta.key 1
ns-cert-type server
cipher AES-256-CBC
compress lz4
verb 3
fast-io
auth SHA512
script-security 2
socks-proxy-retry
socks-proxy 127.0.0.1 1050
EOL
cd $HOME/client-files
# Now merge certs and keys into client script, so we only have one file to handle
wget https://raw.githubusercontent.com/khavishbhundoo/obfsproxy-openvpn/master/merge.sh -O merge.sh
sudo chmod +x merge.sh
sudo ./merge.sh
chown $USER $HOME/client-files/scrambled-client.ovpn
#
cat > /etc/openvpn/server.conf <<EOL
port 443
proto tcp #for obfsproxy, otherwise udp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
tls-auth /etc/openvpn/ta.key 0
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384
dh /etc/openvpn/dh2048.pem
server 10.8.0.0 255.255.255.0
cipher AES-256-CBC
comp-lzo
persist-key
persist-tun
user openvpn      
group openvpn    
status openvpn-status.log
verb 3
tun-mtu 1500
tun-mtu-extra 32
mssfix 1450
push "redirect-gateway def1"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 5 30
auth SHA512
reneg-sec 60
EOL

#creating openvpn group and user
/usr/sbin/groupadd openvpn
useradd -G openvpn openvpn
systemctl restart openvpn@server
} &> /dev/null
echo "Adding proper firewall and ip forwarding rules"
{
#
#Enable IP packet forwarding so that our VPN traffic can pass through.
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf 
grep -qF "net.ipv4.ip_forward" /etc/sysctl.conf  || echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf #Add setting to sysctl.conf if needed
sysctl -p
#Adding proper firewall rules
firewall-cmd --permanent  --add-service http
firewall-cmd --permanent  --add-service https
firewall-cmd --permanent  --add-service openvpn
firewall-cmd --permanent  --add-masquerade
firewall-cmd --permanent  --add-port=21194/tcp
firewall-cmd --permanent  --add-port=443/tcp
firewall-cmd --reload
} &> /dev/null
cat > $HOME/details.txt <<EOF
#########################################
#Scrambled OpenVpn Server Setup Complete#             
#########################################
External IP : ${ipaddr}
Cilent config: ${HOME}/client-files/scrambled-client.ovpn 
Copy client config to the config folder of your OpenVPN installation
Read Tutorial @ https://github.com/khavishbhundoo/obfsproxy-openvpn/ and setup obfsproxy on your computer
EOF
cat $HOME/details.txt
