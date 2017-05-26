cd /home/stack/
source create_servers.sh

HOST_ID="n17"
HOST_ZONE="compute-${HOST_ID}-001"
SERVER_ID="${HOST_ID}-001-02"

create_server $SERVER_ID $HOST_ZONE
/home/stack/kill_dnsmasq.sh
sleep 2

# TAP_IF="tapd4a66a62-eb"
# sudo tcpdump -n -i $TAP_IF -s 65535 -w ${HOST_ZONE}-01.pcap &
# TCPDUMP_PID=$!
# sudo kill -15 $TCPDUMP_PID
