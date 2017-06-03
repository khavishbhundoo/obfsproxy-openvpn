#!/bin/bash
cat <<EOF
#########################################################################
#       Setup OpenVPN + Obfsproxy to bypass Advanced Firewall           # 
#       Bypass Advanced Internet Censorship                             #
#       Github : https://github.com/khavishbhundoo/obfsproxy-openvpn/   #                                                             #
#       Author : Khavish Anshudass Bhundoo                              #
#########################################################################      
EOF
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

if [[ ! -e /dev/net/tun ]]; then
	echo "TUN is not available"
	exit 2
fi

{
yum -y -q install redhat-lsb-core # installing lsb_release
os=$(lsb_release -si) #CentOS
version=$(lsb_release -sr | sed 's/\.[^ ]*/ /g') # Version = 7
} &> /dev/null

if [[ "$os" != "CentOS" && "$version" != "7" ]]; then 
echo "You need to have Centos 7.x installed"
exit 3
fi


function newinstall 
{
read -n1 -r -p "Use default certificates details (y/n)? : "   choice
if [[ $choice = "" ]]; then 
choice="y"
fi
if [[ ! $choice =~ ^[Yy]$ ]] ; then
echo "Please enter your custom certificates details below.All fields are mandatory"
while [[ -z "$KEY_COUNTRY" ]]
do
read -r -p "Country : "   KEY_COUNTRY
done

while [[ -z "$KEY_PROVINCE" ]]
do
read -r -p "Province : "  KEY_PROVINCE
done

while [[ -z "$KEY_CITY" ]]
do
read -r -p "City : "   KEY_CITY
done

while [[ -z "$KEY_ORG" ]]
do
read -r -p "Organization : "  KEY_ORG
done

while [[ -z "$KEY_ORG" ]]
do
read -r -p "Email : "   KEY_EMAIL
done

while [[ -z "$KEY_ORG" ]]
do
read -r -p "Organizational Unit : "  KEY_OU
done


fi

read -r -p "Enable user/password authentication (y/n)? : "   auth_choice
if [[ $auth_choice = "" ]]; then 
auth_choice="y"
fi
if [[ $auth_choice =~ ^[Yy]$ ]] ; then
while [[ -z "$cilent_user" ]]
do
read -r  -p  "Desired username: "   cilent_user
if getent passwd "$cilent_user" > /dev/null 2>&1; then
# cilent_user already  exists
unset "$cilent_user"
fi
done 
fi
echo "That's all we need ...Setup starting!"
#Checking swap
if [[ -n $(/sbin/swapon -s | grep -q /dev) ]]; then
    :
else
echo  "Creating 512MB of swap space as no swap space currently exist"
#Create and activate a 512MB swap file
{
    dd if=/dev/zero of=/swapfile1 bs=1024 count=524288
	mkswap /swapfile1
	chown "$USER":"$USER" /swapfile1
	chmod 0600 /swapfile1
	swapon /swapfile1
	echo "/swapfile1 swap swap defaults 0 0" >> /etc/fstab
	swapoff -a
	swapon -a
} &> /dev/null
fi	
#
#Setting Home directory
HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)

if [[ ! $(rpm -qa | grep -w epel-release) ]]; then
echo  "Setting Up EPEL  Repository"
{
yum -y -q install wget
wget -q https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo rpm -Uvh epel-release-latest-7.noarch.rpm
rm -rf epel-release-latest-7.noarch.rpm
#
} &> /dev/null
fi
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
yum -y -q install yum-utils mlocate
updatedb
timedhosts_file=$(locate timedhosts.txt)
#Get fresh list of fastest mirrors
rm -rf "$timedhosts_file"
package-cleanup --cleandupes > /dev/null
yum -y -q upgrade 
yum -y -q update
} &> /dev/null
echo "Server Softwares and Kernel Updated...." 
#Installing some commonly used tools
echo "Installing useful tools{nano , wget, make}"
{
yum -y -q install nano wget make 
} 2>&1 | grep -v "already installed and latest version"
echo "Installing OpenVPN"
{
yum -y -q remove openvpn
yum -y -q install openvpn
systemctl start openvpn@server
systemctl -f enable openvpn@server.service
} &> /dev/null
echo "Installing obfsproxy"
{
yum install -y -q make automake gcc python-pip python-devel libyaml-devel
pip install --upgrade pip
pip install --upgrade obfsproxy 
yum install -y -q screen
screen -d -m obfsproxy --log-file=obfsproxy.log --log-min-severity=info obfs3 --dest=127.0.0.1:443 server 0.0.0.0:21194 
echo "obfsproxy --log-file=obfsproxy.log --log-min-severity=info obfs3 --dest=127.0.0.1:443 server 0.0.0.0:21194" >> /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local
} &> /dev/null
#Downloading Easy RSA package to create keys and certificates
echo "Setting Up Keys and Certificates(This might take a while)"
{
yum remove -y -q easy-rsa
yum install -y -q easy-rsa
rsync -av /usr/share/easy-rsa/ /etc/openvpn/easy-rsa/
chown -R "$USER" /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa/2.0/
if [[ ! $choice =~ ^[Yy]$ ]] ; then
#Comment default values in file
sed -i 's/export KEY_COUNTRY="US"/#export KEY_COUNTRY="US"/g' /etc/openvpn/easy-rsa/2.0/vars
sed -i 's/export KEY_PROVINCE="CA"/#export KEY_PROVINCE="CA"/g' /etc/openvpn/easy-rsa/2.0/vars
sed -i 's/export KEY_CITY="SanFrancisco"/#export KEY_CITY="SanFrancisco"/g' /etc/openvpn/easy-rsa/2.0/vars
sed -i 's/export KEY_ORG="Fort-Funston"/#export KEY_ORG="Fort-Funston"/g' /etc/openvpn/easy-rsa/2.0/vars
sed -i 's/export KEY_EMAIL="me@myhost.mydomain"/#export KEY_EMAIL="me@myhost.mydomain""/g' /etc/openvpn/easy-rsa/2.0/vars
sed -i 's/export KEY_OU="MyOrganizationalUnit"/#export KEY_OU="MyOrganizationalUnit"/g' /etc/openvpn/easy-rsa/2.0/vars
#Add our custom certificates values
{
echo "export KEY_COUNTRY=\"$KEY_COUNTRY\""
echo "export KEY_PROVINCE=\"$KEY_PROVINCE\""
echo "export KEY_CITY=\"$KEY_CITY\""
echo "export KEY_ORG=\"$KEY_ORG\""
echo "export KEY_EMAIL=\"$KEY_EMAIL\"" 
echo "export KEY_OU=\"$KEY_OU\""
} >> /etc/openvpn/easy-rsa/2.0/vars
fi
#At this point we should have vars set up 
source vars
#
./clean-all
./build-dh
./build-ca --batch
./build-key-server --batch server
if [[ ! $auth_choice =~ ^[Yy]$ ]] ; then
cilent_user="cilent"
fi

./build-key --batch "$cilent_user"
cd /etc/openvpn/easy-rsa/2.0/keys 
cp ca.crt ca.key dh2048.pem server.crt server.key /etc/openvpn
mkdir -p "$HOME"/client-files/"$cilent_user"
cp ca.crt "$cilent_user".crt "$cilent_user".key "$HOME"/client-files/"$cilent_user"
openvpn --genkey --secret /etc/openvpn/ta.key
cp /etc/openvpn/ta.key "$HOME"/client-files/"$cilent_user"
} &> /dev/null



echo "Configuring OpenVPN with obfsproxy"
{
ipaddr=$(curl -s http://whatismyip.akamai.com/)
cat > "$HOME"/client-files/"$cilent_user"/scrambled-client.ovpn <<EOL
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
#Uncomment if you use user/pass authentication
#auth-user-pass
block-outside-dns
verb 3
auth SHA512
script-security 2
socks-proxy-retry
socks-proxy 127.0.0.1 1050
EOL
cd "$HOME"/client-files/"$cilent_user"
# Now merge certs and keys into client script, so we only have one file to handle
wget -q https://www.dropbox.com/s/gjbrl4xm1uv5wkx/merge.sh?dl=0 -O merge.sh
sudo chmod +x merge.sh
sudo ./merge.sh "$cilent_user" scrambled-client
chown "$USER" "$HOME"/client-files/"$cilent_user"/scrambled-client.ovpn
rm -rf merge.sh
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
crl-verify /etc/openvpn/crl.pem
cipher AES-256-CBC
compress lz4
persist-key
persist-tun
user openvpn      
group openvpn    
status openvpn-status.log
#Uncomment if you want user/pass authentication
#plugin /usr/lib64/openvpn/plugins/openvpn-plugin-auth-pam.so login
verb 3
tun-mtu 1500
tun-mtu-extra 32
mssfix 1450
push "redirect-gateway def1"
push "dhcp-option DNS 8.8.8.8" #Google DNS
push "dhcp-option DNS 8.8.4.4"
push "dhcp-option DNS 208.67.222.222" #OpenDNS
push "dhcp-option DNS 208.67.220.220"
keepalive 5 30
auth SHA512
reneg-sec 60
EOL


if [[ $auth_choice =~ ^[Yy]$ ]] ; then
sed -i 's/#auth-user-pass/auth-user-pass/g' "$HOME"/client-files/"$cilent_user"/scrambled-client.ovpn
sed -i 's|#plugin /usr/lib64/openvpn/plugins/openvpn-plugin-auth-pam.so login|plugin /usr/lib64/openvpn/plugins/openvpn-plugin-auth-pam.so loging' /etc/openvpn/server.conf
useradd -M -N -r -s /bin/false -c "OpenVPN cilent : $cilent_user" 
yum -y -q install pwgen
userpass=$(pwgen -1 -s 10) 
echo -e "$userpass\n$userpass" | passwd --stdin "$cilent_user"
fi

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
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent  --add-service http
firewall-cmd --permanent  --add-service https
firewall-cmd --permanent  --add-service openvpn
firewall-cmd --permanent  --add-masquerade
firewall-cmd --permanent  --add-port=21194/tcp
firewall-cmd --permanent  --add-port=443/tcp
firewall-cmd --reload
} &> /dev/null
echo "Setting up a cronjob to auto update OpenVPN and obsproxy"
{
yum -y -q install cronie
systemctl enable crond.service
systemctl start crond.service
yum -y -q install cronie-noanacron
cat > /etc/cron.daily/openvpn.cron << EOF
#!/bin/bash
CURRENT_OPENVPN=$(openvpn --version | cut -d' ' -f2 | awk '{print $1; exit}')
yum -y -q update
RECENT_OPENVPN=$(openvpn --version | cut -d' ' -f2 | awk '{print $1; exit}')
test $RECENT_OPENVPN = $CURRENT_OPENVPN || echo systemctl restart openvpn@server
pip install --upgrade pip
pip install --upgrade obfsproxy
LAST_KERNEL=$(rpm -q --last kernel | perl -pe 's/^kernel-(\S+).*/$1/' | head -1)
CURRENT_KERNEL=$(uname -r)
test $LAST_KERNEL = $CURRENT_KERNEL || echo REBOOT
EOF
chmod +x /etc/cron.daily/openvpn.cron
} &> /dev/null
cat > "$HOME"/details.txt <<EOF
#########################################
#Scrambled OpenVpn Server Setup Complete#             
#########################################
External IP : ${ipaddr}
Cilent config: ${HOME}/client-files/${cilent_user}/scrambled-client.ovpn 
Copy client config to the config folder of your OpenVPN installation
Read Tutorial @ https://github.com/khavishbhundoo/obfsproxy-openvpn/ and setup obfsproxy on your computer
EOF
if [[ $auth_choice =~ ^[Yy]$ ]] ; then
cat >> "$HOME"/details.txt <<EOF
Client username :  ${cilent_user}
Client password :  ${userpass}
EOF
fi
cat "$HOME"/details.txt
}

function add_client
{
HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
while [[ -z "$cilent_user" ]]
do
read -r  -p  "Cilent username: "   cilent_user
if getent passwd "$cilent_user" > /dev/null 2>&1; then
# cilent_user already  exists
unset "$cilent_user"
fi
done 
echo "Creating certificates for $cilent_user"
#Building the certificates
{
cd /etc/openvpn/easy-rsa/2.0/
source vars
./build-key --batch "$cilent_user"
mkdir -p "$HOME"/client-files/"$cilent_user"
ipaddr=$(curl -s http://whatismyip.akamai.com/)
cat > "$HOME"/client-files/"$cilent_user"/scrambled-client.ovpn <<EOL
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
#Uncomment if you use user/pass authentication
#auth-user-pass
block-outside-dns
verb 3
auth SHA512
script-security 2
socks-proxy-retry
socks-proxy 127.0.0.1 1050
EOL
cd /etc/openvpn/easy-rsa/2.0/keys 
cp ca.crt "$cilent_user".crt "$cilent_user".key "$HOME"/client-files/"$cilent_user"
cp /etc/openvpn/ta.key "$HOME"/client-files/"$cilent_user"
cd "$HOME"/client-files/"$cilent_user"
# Now merge certs and keys into client script, so we only have one file to handle
wget -q https://raw.githubusercontent.com/khavishbhundoo/obfsproxy-openvpn/master/merge.sh -O merge.sh
sudo chmod +x merge.sh
sudo ./merge.sh "$cilent_user" scrambled-client
chown "$USER" "$HOME"/client-files/"$cilent_user"/scrambled-client.ovpn
rm -rf merge.sh

# Check if user / pass authentication is used
if [[ $(grep -o '^[^#]*' /etc/openvpn/server.conf | grep "openvpn-plugin-auth-pam.so") ]] ; then
#Add new user account + generate password
useradd -M -N -r -s /bin/false -c "OpenVPN cilent : $cilent_user"
userpass=$(pwgen -1 -s 10) 
echo -e "$userpass\n$userpass" | passwd --stdin "$cilent_user"
sed -i 's/#auth-user-pass/auth-user-pass/g' "$HOME"/client-files/"$cilent_user"/scrambled-client.ovpn
cat >> "$HOME"/details.txt <<EOF
#########################################
#Client Added Successfully              #             
#########################################
Cilent config: ${HOME}/client-files/${cilent_user}/scrambled-client.ovpn 
Client username :  ${cilent_user}
Client password :  ${userpass}
EOF
else 
cat >> "$HOME"/details.txt <<EOF
#########################################
#Client Added Successfully              #             
#########################################
Cilent config: ${HOME}/client-files/${cilent_user}/scrambled-client.ovpn 
EOF
fi
} &> /dev/null
cat "$HOME"/details.txt
}


function delete_client 
{
#Setting Home directory
HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
read -r -p "Type the client username which you want to delete : "  cilent
{
# Check if user / pass authentication is used
if [[ $(grep -o '^[^#]*' /etc/openvpn/server.conf | grep "openvpn-plugin-auth-pam.so") ]] ; then
userdel -Z -r -f "$cilent"
fi
rm -rf "$HOME"/client-files/"$cilent"
cd /etc/openvpn/easy-rsa/2.0/
./revoke-full "$cilent"
systemctl reload-or-restart openvpn@server
} &> /dev/null
echo "$cilent have been removed successfully"
}

PS3='Please enter your choice(1-4): '
options=("First Install" "Add Cilent" "Delete Cilent" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "First Install")
		    newinstall
			break
            ;;
        "Add Cilent")
            add_client
			break
            ;;
        "Delete Cilent")
            delete_client
			break
            ;;
        "Quit")
            break
            ;;
        *) echo invalid option;;
    esac
done
