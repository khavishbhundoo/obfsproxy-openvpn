#!/bin/bash
#######################################################################
#       Latest versions of Openvpn supports inline certs and keys 
#       so you have one client script, instead of script plus 4 keys and certs
#
#       This tool assumes 
#       1) Openvpn script and certs plus keys are in same directory
#       2) Certs are usually specified in Openvpn script like 
#          ca ca.crt 
#             or 
#          ca /etc/local/openvpn/ca.crt 
########################################################################
#  Name of certs and keys and client ovpn script
#
 
ca="ca.crt"
cert="client.crt"
key="client.key"
tlsauth="ta.key"
ovpndest="scrambled-client.ovpn"
 
########################################################################
#   Backup to new subdirectory, just incase
#
mkdir -p backup
cp $ca $cert $key $tlsauth $ovpndest ./backup
 
########################################################################
#   Delete existing call to keys and certs
#
    sed -i \
    -e '/ca .*'$ca'/d'  \
    -e '/cert .*'$cert'/d' \
    -e '/key .*'$key'/d' \
    -e '/tls-auth .*'$tlsauth'/d' $ovpndest 
 
########################################################################
#   Add keys and certs inline
#
echo "key-direction 1" >> $ovpndest
 
echo "<ca>" >> $ovpndest
awk /BEGIN/,/END/ < ./$ca >> $ovpndest
echo "</ca>" >> $ovpndest
 
echo "<cert>" >> $ovpndest
awk /BEGIN/,/END/ < ./$cert >> $ovpndest
echo "</cert>" >> $ovpndest
 
echo "<key>" >> $ovpndest
awk /BEGIN/,/END/ < ./$key >> $ovpndest
echo "</key>" >> $ovpndest
 
echo "<tls-auth>" >> $ovpndest
awk /BEGIN/,/END/ < ./$tlsauth >> $ovpndest
echo "</tls-auth>" >> $ovpndest
 
########################################################################
#   Delete key and cert files, backup already made hopefully
#
rm $ca $cert $key $tlsauth
