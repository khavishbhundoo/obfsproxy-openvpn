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
#  Arguments list:
#  $1 - cilent name
#  $2 - destination ovpn file
#
   
ca="ca.crt"
cert="$1.crt"
key="$1.key"
tlscrypt="ta.key"
ovpndest="$2.ovpn"
   
########################################################################
#   Delete existing call to keys and certs
#
    sed -i \
    -e '/ca .*'$ca'/d'  \
    -e '/cert .*'$cert'/d' \
    -e '/key .*'$key'/d' \
    -e '/tls-crypt .*'$tlscrypt'/d' $ovpndest 
   
########################################################################
#   Add keys and certs inline
#
#echo "key-direction 1" >> $ovpndest
   
echo "<ca>" >> $ovpndest
awk /BEGIN/,/END/ < ./$ca >> $ovpndest
echo "</ca>" >> $ovpndest
   
echo "<cert>" >> $ovpndest
awk /BEGIN/,/END/ < ./$cert >> $ovpndest
echo "</cert>" >> $ovpndest
   
echo "<key>" >> $ovpndest
awk /BEGIN/,/END/ < ./$key >> $ovpndest
echo "</key>" >> $ovpndest
   
echo "<tls-crypt>" >> $ovpndest
awk /BEGIN/,/END/ < ./$tlscrypt >> $ovpndest
echo "</tls-crypt>" >> $ovpndest
   
########################################################################
#   Delete key and cert files
#
rm $ca $cert $key $tlsauth
