# obfsproxy-openvpn
ISPs in high authorian regimes such as in China , Iran and Pakistan can easily detect and broke standard VPN traffic.This bash script automatically install OpenVPN and  Obfsproxy to [obsfucate openvpn traffic](https://community.openvpn.net/openvpn/wiki/TrafficObfuscation) making it very difficult to detect and block.At the time of this writing this method successfully bypasses current firewalls and internet filters.

# Prerequisits
This bash script is compatible with Centos 7 / RHEL 7.x OS. 

Wget has to be installed 

`yum install -y wget `

# Installation

You will need `wget` and root previleges to execute the script on your server

Run the following after having logined as a user with admin privileges to execute the script

`wget https://raw.githubusercontent.com/khavishbhundoo/obfsproxy-openvpn/master/vpn.sh -O vpn.sh && sudo bash vpn.sh`


After the execution is complete , download the `scrambled-client.ovpn` file and reboot the server

# Usage
This section will consist of detailed instructions on how to connect to the VPN 

### Windows
1.Download and Install the [latest version of OpenVPN](https://openvpn.net/index.php/open-source/downloads.html)

2.Copy the file `scrambled-client.ovpn` to `C:\Program Files\OpenVPN\config` directory

3.Install Obfsproxy

You would need to install [latest python 2.7.x](https://www.python.org/downloads/) and then run the following commands in cmd

`cd C:\Python27\Scripts` 

`pip install --upgrade pip` 

`pip install obfsproxy` 

`obfsproxy.exe --log-min-severity info obfs3 socks 127.0.0.1:1050`

Now you can launch OpenVPN and connect to your vpn

Important: before connecting to this server you always need to enter the following commands in the Command Prompt:

`cd C:\Python27\Scripts`

`obfsproxy.exe --log-min-severity info obfs3 socks 127.0.0.1:1050`

The Command Prompt window should remain open or else your vpn connection will be closed

### Linux

1.Install EPEL repository

`yum -y install epel-release`

2.Install latest OpenVPN

`yum -y install openvpn` 

3.Install obfsproxy

You would need to install latest python 2.7.x and then run the following commands

`pip install --upgrade pip` 

`pip install obfsproxy` 
 
`obfsproxy --log-min-severity info obfs3 socks 127.0.0.1:1050`



# Disclaimer
Author is not responsible for any your actions , use this script at your own risk
