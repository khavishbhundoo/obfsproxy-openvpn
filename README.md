# obfsproxy-openvpn
ISPs in high authorian regimes such as in China , Iran and Pakistan can easily detect and block standard VPN traffic.This bash script automatically install OpenVPN and  Obfsproxy to [obsfucate openvpn traffic](https://community.openvpn.net/openvpn/wiki/TrafficObfuscation) making it very difficult to detect and block.At the time of this writing this method successfully bypasses current firewalls and internet filters.

# Prerequisits
This bash script is compatible with Centos 7 / RHEL 7.x OS. 

# Installation

You will need to have root previleges to execute the script on your server

Run the following after having logined as a user with admin privileges to execute the script

`curl -so vpn.sh -L  https://raw.githubusercontent.com/khavishbhundoo/obfsproxy-openvpn/master/vpn.sh  && sudo bash vpn.sh`


After the execution is complete , download the `scrambled-client.ovpn` file.

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

# Firewall rules for Cloud Platforms

If your server is actually a VM instance on cloud platforms like Google Compute Engine(GCE) or Amazon EC2 you need to add a firewall rule manually as well

Below is how it should be if you are on GCE

![firewall](https://github.com/khavishbhundoo/obfsproxy-openvpn/blob/master/firewalld.png)

# Video
[![video tutorial](https://img.youtube.com/vi/BNcowGTHHDI/0.jpg)](https://www.youtube.com/watch?v=BNcowGTHHDI)


# Disclaimer
Author is not responsible for any of your actions , use this script at your own risk

# License
`MIT License

Copyright (c) 2017 Khavish Anshudass Bhundoo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.`
