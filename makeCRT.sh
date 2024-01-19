#!/usr/bin/env bash

#inst-k3s-client V1.0
#Author: RH363
#Date: 10/01/2024

ROOT_UID=0                                                                                                   
USER_UID=$(id -u)                                                                                            
ERR_NOTROOT=86
ERR_INV_OPTION=90
ERR_INV_DAYS=91

CACRTPATH=serverCA.crt
CAKEYPATH=serverCA.key

SERVERNAME=serverCRT
DAYS=4096
# Regular Colors
Color_Off='\033[0m'       # Text Reset

Red='\033[0;31m'          # Red
Blue='\033[0;34m'         # Blue
Yellow='\033[0;33m'       # Yellow

usage() {
 echo "Usage: $0 [OPTIONS]"
 echo "Colors:"
 echo -e "${Red} ERROR" 
 echo -e "${Yellow} WARNING"
 echo -e "${Blue} INFO ${Color_Off}"
 echo "Options:"
 echo " -h, --help            Display this help message"
 echo ' -c, --ca-cert         CA CERT PATH(DEFAULT="serverCA.crt") Define CA cert PATH'
 echo ' -k, --ca-key          CA KEY PATH(DEFAULT="serverCA.key") Define CA key PATH'
 echo " -d, --days            DAYS(DEFAULT=4096) Define how much days this cert must be valid"
 echo ' -s, --server          SERVER NAME(DEFAULT="serverCRT") Define server cert name '

}


while (($# > 0)); do
    case "$1" in
        "-h"|"--help")
            usage
            exit
        ;;
        "-s"|"--server")
            if [ -z "$2" ];then
                echo -e "${Red}SERVER NAME OPTION REQUIRE AN ARGUMENT${Color_Off}"
                exit $ERR_INV_OPTION
            fi
            SERVERNAME=$2
            shift 2
        ;;
        "-c"|"--ca-cert")
            if [ -z "$2" ];then
                echo -e "${Red}CA CERT PATH OPTION REQUIRE AN ARGUMENT${Color_Off}"
                exit $ERR_INV_OPTION
            fi
            CACRTPATH=$2
            shift 2
        ;;
        "-k"|"--ca-key")
            if [ -z "$2" ];then
                echo -e "${Red}CA KEY PATH OPTION REQUIRE AN ARGUMENT${Color_Off}"
                exit $ERR_INV_OPTION
            fi
            CAKEYPATH=$2
            shift 2
        ;;
        "-d"|"--days")
            if [ -z "$2" ];then
                echo -e "${Red}DAYS OPTION REQUIRE AN ARGUMENT${Color_Off}"
                exit $ERR_INV_OPTION
            fi
            if ! [[ $2 =~ ^[0-9]+$ ]]; then 
                echo -e "${Red}ERROR: $2 INVALID NUMBER${Color_Off}"
                exit $ERR_INV_DAYS
            fi
            DAYS=$2
            shift 2
        ;;
        *)
            echo -e "${Red}INVALID OPTION: $1${Color_Off}"
            exit $ERR_INV_OPTION
        ;;
    esac
done

if [ "$USER_UID" -ne "$ROOT_UID" ]                                                                           
    then
    echo -e "${Red}MUST BE ROOT TO RUN THIS SCRIPT${Color_Off}"
    exit $ERR_NOTROOT
    fi

if [ "$PWD" != "$SERVERNAME" ];then 
    mkdir "$SERVERNAME"
fi

case "$(lsb_release -is)" in
    "Ubuntu"|"Debian")
        apt-get -y install openssl 
    ;;
    "Almalinux")
        dnf -y install openssl
    ;;
    *)

    ;;
esac
echo -e "${Blue}CREATE CSR${Color_Off}"
openssl req -new -nodes -out "$SERVERNAME/$SERVERNAME".csr -newkey rsa:4096 -keyout "$SERVERNAME/$SERVERNAME".key
if [ $? != 0 ];then
    rm -rf "$SERVERNAME"
    exit
fi
echo -e "${Blue}CSR CREATED${Color_Off}"
echo "authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]">"$SERVERNAME/$SERVERNAME".v3.ext

echo -e "${Blue}insert DNS alternative names:(backspace for save setting)${Color_Off}"
c=1
while read -r dns && [ -n "$dns" ]; do
   echo "DNS.$c = $dns" >> "$SERVERNAME/$SERVERNAME".v3.ext
   (( c+=1 ))
done

echo -e "${Blue}insert IP alternative:(backspace for save setting)${Color_Off}"
c=1
while read -r ip && [ -n "$ip" ]; do
   echo "IP.$c = $ip" >> "$SERVERNAME/$SERVERNAME".v3.ext
   (( c+=1 ))
done

echo -e "${Blue}CREATE SERVER CERT${Color_Off}"
openssl x509 -req -in "$SERVERNAME"/"$SERVERNAME".csr -CA "$CACRTPATH" -CAkey "$CAKEYPATH" -CAcreateserial -out "$SERVERNAME"/"$SERVERNAME".crt -days "$DAYS" -sha256 -extfile "$SERVERNAME"/"$SERVERNAME".v3.ext
if [ $? != 0 ];then
    rm -rf "$SERVERNAME"
    exit
fi
echo -e "${Blue}SERVER CERT CREATED${Color_Off}"
cp "$SERVERNAME"/"$SERVERNAME".crt "$SERVERNAME"/"$SERVERNAME".pem
