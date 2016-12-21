#!/bin/bash  
 while [[ -n $1 ]]; do 
      echo "$1	ALL=(ALL) NOPASSWD: /usr/sbin/tcpdump" >> /etc/sudoers; 
      echo "$1	ALL=(ALL) NOPASSWD: /bin/netstat" >> /etc/sudoers; 
      shift # shift all parameters; 
