#!/usr/bin/env bash
# Author : amr
# Project Name : PassiveDNS_SVC
# License : GPLv3 or later



# Copyright (C) 2026 Amr Alasmer



# PassiveDNS_SVC  is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later 
# version.

# PassiveDNS_SVC is distributed in the hope that it will be useful, but WITHOUT 
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.


set -x

# change this to your network interface you want to monitor, or use the interface name as argument
# to this script, for example `./pdns.sh eth0`
NetworkInterface=''




# build network interface option 'the interface we would listen on'
NeworkInterfaceOption=""
if [[ ! -z "$NetworkInterface" ]]; then 
    NeworkInterfaceOption="-i ${NetworkInterface}"
else 
    for arg in "$@"; do 
        if [[ "$arg" != "-d" ]]; then 
            NetworkInterface="$arg"
            break
        fi
    done
fi
arg=""



if [[  -z "$NetworkInterface" ]]   ; then 
    echo "Please specify network interface you want to monitor by use it's 
name as argument to this script, for example:
$0 eth0
or edit the $0 script file, and change the value of 'NetworkInterface' variable 
to the network interface you want to monitor"
    exit 3 
fi

# validte the interface
/usr/bin/env ip stats show dev "$NetworkInterface" &>/dev/null 
tmpst=$?
    

if [[  "$tmpst" -ne 0 ]]; then 
    echo "Invalid Network Interface '$NetworkInterface', select one of those interfaces:
`/usr/bin/env basename -a /sys/class/net/*`"
    exit 4
fi

PassiveDnsDir="/opt/passivedns"
UserAccount="passivedns"
ServiceName="passivedns"

Debian_install(){
    /usr/bin/env sudo /usr/bin/env apt update || return $?
    /usr/bin/env sudo /usr/bin/env apt install git build-essential libldns-dev libpcap-dev automake autoconf  || return $?
    /usr/bin/env sudo /usr/bin/env apt install libdate-simple-perl  || return $?

}
Red_install(){
  /usr/bin/env yum groupinstall "Development tools"  || return $?
  /usr/bin/env rpm -Uvh http://download.fedoraproject.org/pub/epel/6/x86_64/ldns-devel-1.6.11-2.el6.x86_64.rpm  || return $?
  /usr/bin/env rpm -Uvh http://download.fedoraproject.org/pub/epel/6/x86_64/ldns-1.6.11-2.el6.x86_64.rpm  || return $?
  /usr/bin/env wget http://www.tcpdump.org/release/libpcap-1.2.1.tar.gz  || return $?
  /usr/bin/env tar zxf libpcap-1.2.1.tar.gz  || return $? 
  cd libpcap-1.2.1 
  ./configure  || return $?
   /usr/bin/env make  || return $?
   /usr/bin/env make install  || return $?
}
Ubuntu_install(){
  /usr/bin/env sudo /usr/bin/env apt-get install git-core binutils-dev libldns1 libldns-dev libpcap-dev  || return $? 
}

deps_install_fallback(){
    echo "please install dependencies for passivedns because the script cannot get your 
operating system, to install dependencies please visit https://github.com/gamelinux/passivedns/blob/master/doc/INSTALL
and use the installation commands that match your system, and rerun this script with -d flag, for example:
$0 $NetworkInterface -d"
    exit 2
}

dep_install(){
    if [[ ! -f /etc/os-release ]]; then 
        ID="`lsb_release -i -s`"
    else
        . /etc/os-release
    fi

    if [[ -z "$ID" ]]; then 
        deps_install_fallback
    fi

    case "${ID,,}" in 
        "debian")
            Debian_install || return $?
            ;;
        "ubuntu")
            Ubuntu_install || return $?
            ;;
        "rhel")
            Red_install || return $?
            ;;
        "fedora")
            Red_install || return $?
            ;;
        *)
            deps_install_fallback 
        ;;
    esac
}



deps_installed=0
for arg in "$@"; do 
    if [[ "$arg" == "-d" ]]; then 
        deps_installed=1
    fi 
done 


# install passivedns deps
[[ "$deps_installed" -eq 1 ]] || dep_install

cd ~

# clone passivedns git repo
if [[ ! -d passivedns ]] ; then 
    /usr/bin/env git clone https://github.com/gamelinux/passivedns.git || { echo "cannot clone passivedns git repo" ; exit  1 ; } 
fi


# create service account with no login shell
/usr/bin/env id "$UserAccount" 2>&1 >/dev/null
tmp=$?
if  [[ $tmp -ne 0 ]] ; then
    /usr/bin/env sudo /usr/bin/env useradd -s /usr/sbin/nologin --no-create-home --system "$UserAccount" || { echo "Cannot create user: $UserAccount!" 1>&2 ; exit 1 ; }
fi

# move passivedns dir to /opt and make it owned by passivedns svc user
/usr/bin/env sudo /usr/bin/env mv passivedns /opt/passivedns 
/usr/bin/env sudo /usr/bin/env chown  -R passivedns:passivedns /opt/passivedns 
/usr/bin/env sudo /usr/bin/env chmod 777 /opt/passivedns 
cd /opt/passivedns/

# build passivedns
/usr/bin/env sudo -u passivedns /usr/bin/env autoreconf --install
/usr/bin/env sudo -u passivedns ./configure
/usr/bin/env sudo -u passivedns  /usr/bin/env make
/usr/bin/env sudo /usr/bin/env chmod 755 /opt/passivedns 






RunScript="${PassiveDnsDir}/run.sh"
RelaodScript="${PassiveDnsDir}/reload.sh"
StopScript="${PassiveDnsDir}/stop.sh"


# build run script
if [[ ! -f "$RunScript" ]]  ; then
    RunScriptContent="#!/usr/bin/env bash
/opt/passivedns/src/passivedns -D -P 3  -y -l /var/log/passivedns.log -X 46CDNPRSFTMn -u \`/usr/bin/env id passivedns -u\` -g \`/usr/bin/env id passivedns -g\`  $NeworkInterfaceOption"
    echo "$RunScriptContent" | /usr/bin/env  sudo -u passivedns /usr/bin/env tee  "$RunScript"
    /usr/bin/env sudo /usr/bin/env chown passivedns "$RunScript"
    /usr/bin/env sudo /usr/bin/env chmod u+x "$RunScript"
fi




if [[ ! -f "$RelaodScript" ]] || [[ ! -f "$StopScript" ]]  ; then
    StopScriptContent="#!/usr/bin/env bash
kill -9 \`pidof passivedns\`"
    RelaodScriptContent="#!/usr/bin/env bash
/opt/passivedns/stop.sh || exit 1
/opt/passivedns/run.sh || exit 2"

    echo "$RelaodScriptContent" | /usr/bin/env sudo -u passivedns /usr/bin/env tee  "$RelaodScript"
    echo "$StopScriptContent" | /usr/bin/env sudo -u passivedns /usr/bin/env tee  "$StopScript"
    /usr/bin/env sudo -u passivedns /usr/bin/env chmod u+x "$RelaodScript"
    /usr/bin/env sudo -u passivedns /usr/bin/env chmod u+x "$StopScript"

fi




# create the service 
ServiceFile="/etc/systemd/system/$ServiceName.service"

/usr/bin/env systemctl status "$ServiceName" 2>&1 >/dev/null
tmp=$?
if  [ $tmp -ne 0 ] ; then
    /usr/bin/env cat <<EOF | /usr/bin/env sudo /usr/bin/env tee  "$ServiceFile"
[Unit]
Description=passivedns service to monitor dns queries
After=network-online.target
Requires=network-online.target

[Service]
User=root
Group=passivedns
Type=forking
ExecStart=$RunScript
ExecReload=$RelaodScript 
ExecStop=$StopScript
RemainAfterExit=yes


[Install]
WantedBy=multi-user.target

EOF

    /usr/bin/env sudo /usr/bin/env systemctl enable "$ServiceFile" --now

fi

