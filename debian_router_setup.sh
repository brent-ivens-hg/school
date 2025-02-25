#!/bin/bash

apt update && apt upgrade -y
apt install vim bind9 isc-dhcp-server -y

# Enable routing
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
/usr/sbin/sysctl -p

# Setup static IP
/usr/bin/cat << EOF >> /etc/network/interfaces.d/enp0s8
allow-hotplug enp0s8
iface enp0s8 inet static
    address 192.168.100.10
    netmask 255.255.255.0
EOF


# Setup Bind/DNS

/usr/bin/cat << EOF > /etc/bind/named.conf.options
  options {
      directory "/var/cache/bind";

      listen-on port 53 { any; };
      allow-query { any; };
      recursion yes;
      dnssec-validation no;
      forwarders {
              1.1.1.1;
      };
      forward only;
  };
EOF


systemctl enable named
systemctl start named

# Enable NAT'ing
systemctl enable nftables 
systemctl start nftables 


/usr/bin/cat << EOF > /etc/nftables.conf
#!/usr/sbin/nft -f

# Flush the rule set
flush ruleset

# Create a nat table
add table nat
add chain nat prerouting { type nat hook prerouting priority -100 ; }
add chain nat postrouting { type nat hook postrouting priority 100 ; }
add rule nat postrouting oifname "enp0s3" masquerade
EOF

# Configure and enable DHCP
/usr/bin/cat << EOF > /etc/default/isc-dhcp-server
INTERFACESv4="enp0s8"
EOF

/usr/bin/cat << EOF > /etc/dhcp/dhcpd.conf
# dhcpd.conf
option domain-name "hogent.local";
option domain-name-servers 192.168.100.10;

default-lease-time 600;
max-lease-time 7200;

ddns-update-style none;

subnet 192.168.100.0 netmask 255.255.255.0 {
    range 192.168.100.11 192.168.100.100;
    option routers 192.168.100.10;
    option subnet-mask 255.255.255.0;
}
EOF

reboot
