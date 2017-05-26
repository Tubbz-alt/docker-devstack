TAP_IF=""
while [ -z "$TAP_IF" ] ; do 
    echo "waiting for tap-dev to be created"
    sleep 1
    TAP_IF="$(ip -o -4 a s | grep tap | column | cut -d " " -f 2)"
done
echo "Capturing packets on tap: $TAP_IF :" 

DATE=$(date +"%Y%m%dT%H%M%S")
DHCP_FILTER=" port 67 or port 68"
OUTPUT_FILE="-w $(hostname).${DATE}.${TAP_IF}.pcap "
tcpdump -n -i $TAP_IF -s 65535 $DHCP_FILTER $OUTPUT_FILE
