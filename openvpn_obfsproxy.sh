#!/bin/bash
cat <<EOF
#########################################################################
#       Setup OpenVPN + Obfsproxy to bypass Censorship                  #
#       Bypass Advanced Internet Firewalls                              #
#       Github : https://github.com/khavishbhundoo/obfsproxy-openvpn/   #
#       Author : Khavish Anshudass Bhundoo                              #
#########################################################################
EOF
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

if [[ ! -e /dev/net/tun ]]; then
  echo "TUN is not available"
  exit 2
fi

if [ "$1" == "--version" ]; then
  echo 0.2.2
fi

{
  rpm -qa | grep  redhat-lsb-core || yum install -y -q redhat-lsb-core # installing lsb_release if not installed
  os=$(lsb_release -si) #CentOS
  version=$(lsb_release -sr | sed 's/\.[^ ]*/ /g') # Version = 7
} &> /dev/null

if [[ "$os" != "CentOS" && "$os" != "RedHatEnterpriseServer" && "$version" != "7" ]]; then
  echo "You need to have CentOS/RHEL 7.x installed"
  exit 3
fi

function merge_certificates()
{
# $1 $HOME
# $2 $cilent_user
  wget -q https://raw.githubusercontent.com/khavishbhundoo/obfsproxy-openvpn/master/merge.sh -O merge.sh
  sudo chmod +x merge.sh
  sudo ./merge.sh "$2" scrambled-client
  chown "$USER" "$1"/client-files/"$2"/scrambled-client.ovpn
  rm -rf merge.sh
}

function newinstall
{
  cat <<EOF
There is no need to specify information such as Country/State/City/Organisation/Organizational Unit
while generating certificates for VPN usage.However if for reason(s) you want to include organisational
fields in your certificates , choose no otherwise type yes (or press enter)
EOF
  read  -r -p "Use default certificates details (y/n)? : "   choice
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

    while [[ -z "$KEY_EMAIL" ]]
    do
      read -r -p "Email : "   KEY_EMAIL
    done

    while [[ -z "$KEY_OU" ]]
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
        cilent=""
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
      fallocate -l 512M /swapfile1
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
  echo "Updating server softwares (This might take a while)"
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
    yum -y -q install yum-utils mlocate deltarpm
    updatedb
    timedhosts_file=$(locate timedhosts.txt)
    #Get fresh list of fastest mirrors
    rm -rf "$timedhosts_file"
    package-cleanup --cleandupes > /dev/null
    yum -y -q upgrade
    yum -y -q update
  } &> /dev/null
  echo "Server Softwares Updated!"
#Installing some commonly used tools
  echo "Installing useful tools{nano , wget, make}"
  {
    yum -y -q install nano wget make rsync
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
    wget -q https://github.com/OpenVPN/easy-rsa/releases/download/3.0.1/EasyRSA-3.0.1.tgz
    tar -xzf EasyRSA-3.0.1.tgz
    rsync -av ./EasyRSA-3.0.1/ /etc/openvpn/easy-rsa/
    chown -R "$USER" /etc/openvpn/easy-rsa/
    cd /etc/openvpn/easy-rsa/
    if [[ ! $choice =~ ^[Yy]$ ]] ; then
    #Add our custom certificates values
      {
        echo "set_var EASYRSA_ALGO ec"
        echo "set_var EASYRSA_CURVE secp521r1"
        echo "set_var EASYRSA_DIGEST \"sha512\""
        echo "set_var EASYRSA_DN \"org\""
        echo "set_var EASYRSA_REQ_COUNTRY \"$KEY_COUNTRY\""
        echo "set_var EASYRSA_REQ_PROVINCE \"$KEY_PROVINCE\""
        echo "set_var EASYRSA_REQ_CITY \"$KEY_CITY\""
        echo "set_var EASYRSA_REQ_ORG \"$KEY_ORG\""
        echo "set_var EASYRSA_REQ_EMAIL \"$KEY_EMAIL\""
        echo "set_var EASYRSA_REQ_OU \"$KEY_OU\""
      } >> /etc/openvpn/easy-rsa/vars
    else
      {
        #by default use elliptic curve
        echo "set_var EASYRSA_ALGO ec"
        echo "set_var EASYRSA_CURVE secp521r1"
        echo "set_var EASYRSA_DIGEST \"sha512\""
      } >> /etc/openvpn/easy-rsa/vars
    fi

    ./easyrsa init-pki
    ./easyrsa --batch build-ca nopass
    ./easyrsa build-server-full server nopass
    if [[ ! $auth_choice =~ ^[Yy]$ ]] ; then
      cilent_user="cilent"
    fi
    ./easyrsa build-client-full "$cilent_user" nopass
    ./easyrsa gen-crl
    cp pki/ca.crt pki/private/ca.key  pki/issued/server.crt pki/private/server.key /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn
    mkdir -p "$HOME"/client-files/"$cilent_user"
    cp pki/ca.crt  pki/issued/"$cilent_user".crt pki/private/"$cilent_user".key  "$HOME"/client-files/"$cilent_user"
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
tls-crypt  ta.key
tls-client
remote-cert-tls server
cipher AES-256-GCM
compress lz4
#Uncomment if you use user/pass authentication
#auth-user-pass
block-outside-dns
verb 3
auth SHA512
script-security 2
socks-proxy 127.0.0.1 1050
EOL
    cd "$HOME"/client-files/"$cilent_user"
    merge_certificates "$HOME" "$cilent_user"
    cat > /etc/openvpn/server.conf <<EOL
port 443
proto tcp #for obfsproxy, otherwise udp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
tls-crypt /etc/openvpn/ta.key
tls-version-min 1.2
tls-cipher TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384
tls-server
dh none
ecdh-curve sect571r1
server 10.8.0.0 255.255.255.0
#Uncomment when removing certificates
#crl-verify /etc/openvpn/crl.pem
cipher AES-256-GCM
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
      sed -i 's|#plugin /usr/lib64/openvpn/plugins/openvpn-plugin-auth-pam.so login|plugin /usr/lib64/openvpn/plugins/openvpn-plugin-auth-pam.so login|g' /etc/openvpn/server.conf
      useradd -M -N -r -s /bin/false -c "OpenVPN cilent" "$cilent_user"
      yum -y -q install pwgen
      userpass=$(pwgen -1 -s 10)
      chpasswd <<< "$cilent_user:$userpass"
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
CURRENT_OPENVPN=\$(openvpn --version | cut -d' ' -f2 | awk '{print $1; exit}')
yum -y -q update
RECENT_OPENVPN=\$(openvpn --version | cut -d' ' -f2 | awk '{print $1; exit}')
test \$RECENT_OPENVPN = \$CURRENT_OPENVPN || echo systemctl restart openvpn@server
pip install --upgrade pip
pip install --upgrade obfsproxy
LAST_KERNEL=\$(rpm -q --last kernel | perl -pe 's/^kernel-(\S+).*/$1/' | head -1)
CURRENT_KERNEL=\$(uname -r)
test \$LAST_KERNEL = \$CURRENT_KERNEL || echo REBOOT
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
Client username : ${cilent_user}
Client password : ${userpass}
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
	#check if  user account exist if we are using user/password
	if [[ $(grep -o '^[^#]*' /etc/openvpn/server.conf | grep "openvpn-plugin-auth-pam.so") ]] ; then
    if getent passwd "$cilent_user" > /dev/null 2>&1; then
	  echo "cilent already exists...Try again!"
      cilent_user=""
    fi
	elif [ -f "$HOME"/client-files/"$cilent_user"/scrambled-client.ovpn ]; then
	  echo "cilent already exists...Try again!"
      cilent_user=""
	fi
  done
  echo "Creating certificates for $cilent_user"
#Building the certificates
  {
    cd /etc/openvpn/easy-rsa/
	./easyrsa build-client-full "$cilent_user" nopass
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
tls-crypt  ta.key
tls-client
remote-cert-tls server
cipher AES-256-GCM
compress lz4
#Uncomment if you use user/pass authentication
#auth-user-pass
block-outside-dns
verb 3
auth SHA512
script-security 2
socks-proxy 127.0.0.1 1050
EOL
    cd /etc/openvpn/easy-rsa/
    cp pki/ca.crt  pki/issued/"$cilent_user".crt pki/private/"$cilent_user".key  "$HOME"/client-files/"$cilent_user"
    cp /etc/openvpn/ta.key "$HOME"/client-files/"$cilent_user"
    cd "$HOME"/client-files/"$cilent_user"
    merge_certificates "$HOME" "$cilent_user"

    # Check if user / pass authentication is used
    if [[ $(grep -o '^[^#]*' /etc/openvpn/server.conf | grep "openvpn-plugin-auth-pam.so") ]] ; then
    #Add new user account + generate password
      useradd -M -N -r -s /bin/false -c "OpenVPN cilent" "$cilent_user"
      userpass=$(pwgen -1 -s 10)
      chpasswd <<< "$cilent_user:$userpass"
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
  while [[ -z "$cilent" ]]
  do
    read -r -p "Type the client username which you want to delete : "  cilent
  done

  read  -r -p "Are you sure you want to delete user $cilent (y/n)? : " choice

  if [[ $choice =~ ^[Yy]$ ]] ; then

  #Check if we are using user / pass authentication
  #Delete the user account associated with that OpenVPN cilent
    if [[ $(grep -o '^[^#]*' /etc/openvpn/server.conf | grep "openvpn-plugin-auth-pam.so") ]] ; then

      #We are using authentication
      #Ensure we are not trying to delete our current user account
      if [[ $cilent == "$SUDO_USER" ]] ; then
        echo "It seems that you are logged in with the user account that you are trying to delete.This situation happens when you enabled user/password authentication after first install.Skipping user account deletion"
      elif ! getent passwd "$cilent" > /dev/null 2>&1;  then
      # Ensure that the user account exist
        echo "The user account named $cilent doesn't exist"
      else
        #At this point we can safely delete the user account
        userdel -Z -r -f "$cilent"
        echo "$cilent user account removed successfully"
      fi

    fi

    #Now we revoke the certificates and reload openvpn
    rm -rf "$HOME"/client-files/"$cilent"
    cd /etc/openvpn/easy-rsa/
    if ./easyrsa --batch revoke "$cilent" | grep -q 'Revoking Certificate'; then
      echo "$cilent certificates revoked successfully"
	  ./easyrsa gen-crl
	  rm -rf pki/reqs/"$cilent".req
	  rm -rf pki/private/"$cilent".key
	  rm -rf pki/issued/"$cilent".crt
      rm -rf /etc/openvpn/crl.pem
      cp /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn/crl.pem
      sed -i 's|#crl-verify /etc/openvpn/crl.pem|crl-verify /etc/openvpn/crl.pem|g' /etc/openvpn/server.conf
    fi
    systemctl reload-or-restart openvpn@server
    cat >> "$HOME"/details.txt <<EOF
#########################################
#Client Deleted Successfully            #
#########################################
${cilent} has been deleted!
EOF

  fi
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
