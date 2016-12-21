#!/bin/bash 
DB_USER='root';
DB_PASSWD='mysqlpass';
DB_NAME='sysinfo';
# capture tcpdump
DATE=$(date +%Y-%m-%d:%H:%M:%S);

filename=$PWD/tst$DATE.pcap
sudo tcpdump  -G 60 -W 1 -w $filename

# write into log return log id
log_id=$(mysql --user=$DB_USER --password=$DB_PASSWD $DB_NAME -B -N -e "INSERT INTO log () VALUES (); select LAST_INSERT_ID();";);

function write_mysql()
{
	# write section
	mysql --user=$DB_USER --password=$DB_PASSWD $DB_NAME -B -N -e "INSERT INTO section (log_id,name,data) VALUES ($log_id,'$1','$2');";
}

write_mysql "Load Average" "$(echo $(nproc;uptime)| awk '{c=$1; f=substr($(NF-2),1,length($(NF-2))-1); s=substr($(NF-1),1,length($(NF-1))-1); t=substr($(NF),1,length($(NF))); gsub(",","",$(NF-2)); if(100*$(NF-2)/c >=100) print "<span_class=\"crit\">"f"</span>"" "s" "t" CPU(S): "c; else if(100*$(NF-2)/c>=1) print "<span_class=\"warn\">"f"</span>"" "s" "t" CPU(S): "c; else print f" "s" "t" CPU(S): "c;}'|awk '{f=$1; s=$2; t=$3; c=$5; gsub(",","",$2); if(100*$2/c>=100) print f" ""<span_class=\"crit\">"s"</span>"" "t" CPU(S): "c; else if(100*$2/c>=70) print f" ""<span_class=\"warn\">"s"</span>"" "t" CPU(S): "c; else print f" "s" "t" CPU(S): "c;}'| awk '{f=$1; s=$2; t=$3; c=$5; gsub(",","",$3); if(100*$3/c>=100) print f" "s" ""<span_class=\"crit\">"t"</span>"" CPU(S): "c; else if(100*$3/c>=70) print f" "s" ""<span_class=\"warn\">"t"</span>"" CPU(S): "c; else print f" "s" "t" CPU(S): "c;}'| awk '{gsub("_"," ",$0); print $0}')";
write_mysql "Disk Load iostat" "$(iostat -x |awk 'NR > 6 {print $0}' |sed -e '$d'| awk 'BEGIN {printf("%10s %10s %10s %10s %10s %10s\n","device","r/s","w/s","rkB/s","wkB/s","%util")}{printf("%10s %10s %10s %10s %10s %10s \n",$1,$4,$5,$6,$7,$14)}')";
write_mysql "Network Load" "$(cat /proc/net/dev |awk ' NR > 2 {print $0}'| awk ' BEGIN {printf("%15s %15s %15s %15s %15s \n","inteface","bytes_recived","packet_recived","bytes_transmit","packet_transmit")} {printf("%15s %15d %15d %15d %15d \n",$1,$2,$3,$10,$11)}')";
# tcpdump
write_mysql "tcpdump by proto,size" "$(sudo tcpdump -nn -r $filename | awk '{print $2 "\t" int($NF)}'|gawk '{a[$1]+=$2; s+=$2} END {PROCINFO["sorted_in"] = "@val_num_desc";for(proto in a) printf( "%15s %15d %d%% \n",proto,a[proto],100*a[proto]/s) }')"
write_mysql "tcpdump Top Talkers src/dst ip, src port, packets, pps" "$(sudo tcpdump -nn -r $filename tcp or udp and not ip6 | awk '{gsub(/\./," ",$3);gsub(/\./," ",$5);print $3" " $5}' |awk '{print $1"."$2"."$3"."$4"  "$6"."$7"."$8"."$9"  "$5}'|gawk '{a[$1" "$2" "$3]+=1; s+=1} END {PROCINFO["sorted_in"] = "@val_num_desc";for(sip_dip_p in a) printf( "%45s %5d %8.2f \n",sip_dip_p,a[sip_dip_p],a[sip_dip_p]/60) }'| awk '{printf("%17s %17s %8s %5d %8.2f\n",$1,$2,$3, $4, $5)}')";
write_mysql "tcpdump Top Talkers src/dst ip, dst port, packets, pps" "$(sudo tcpdump -nn -r $filename tcp or udp and not ip6 | awk '{gsub(/\./," ",$3);gsub(/\./," ",$5);print $3" " $5}' |awk '{print $1"."$2"."$3"."$4"  "$6"."$7"."$8"."$9"  "$10}'|gawk '{a[$1" "$2" "$3]+=1; s+=1} END {PROCINFO["sorted_in"] = "@val_num_desc";for(sip_dip_p in a) printf( "%45s %5d %8.2f \n",sip_dip_p,a[sip_dip_p],a[sip_dip_p]/60) }'| awk '{printf("%17s %17s %8s %5d %8.2f\n",$1,$2,substr($3,1,length($3)-1), $4, $5)}')";
write_mysql "tcpdump Top Talkers src/dst ip, port, bytes, bps" "$(sudo tcpdump -nn -r $filename tcp or udp and not ip6 | awk '{gsub(/\./," ",$3);gsub(/\./," ",$5);print $3" " $5" "$NF}' |awk '{print $1"."$2"."$3"."$4"  "$6"."$7"."$8"."$9"  "$5" "$NF}'|gawk '{a[$1" "$2" "$3]+=$NF; s+=$NF} END {PROCINFO["sorted_in"] = "@val_num_desc";for(sip_dip_p in a) printf( "%45s %5d %8.2f \n",sip_dip_p,a[sip_dip_p],a[sip_dip_p]/60) }'| awk '{printf("%17s %17s %8s %5d %8.2f\n",$1,$2,$3, $4, $5)}')";
# delete old tcpdump files
rm -f $filename
write_mysql "Listening socket" "$(sudo netstat -tulpn | awk 'NR>1 {print $0}')";
write_mysql "CPU load" "$(mpstat | awk 'NR >3{gsub(",",".",$0);printf("%8.1f %%us %8.1f %%sys %8.1f %%idle %8.1f %%iowait \n", $3+$4,$5,$12,$6)}')";
write_mysql "Disk Usage" "$(df --output=source,pcent,ipcent,target|grep -v -E '% /dev|% /proc|% /sys'|awk '{	p=int(substr($2,1,length($2)-1));	i=int(substr($3,1,length($3)-1)); if(i>p) p=i; if( p>=90) print "<span class=\"crit\">"$0"</span>"; else if(p>=80) print "<span class=\"warn\">"$0"</span>"; else print $0;}')";

