#!/bin/bash

minername=$(docker ps -a|grep miner|awk -F" " '{print $NF}')
newheight="1378103"
echo "Snapshot height is $";
echo "Stopping the miner... "
sudo docker stop $minername
echo "Clearing blockchain data... "
sudo rm -rf /home/pi/hnt/miner/blockchain.db
sudo rm -rf /home/pi/hnt/miner/ledger.db
echo -n "Starting the miner... "
sudo docker start $minername
filepath=/tmp/snap-1378103;
if [ ! -f "$filepath" ]; then
  echo "Downloading latest snapshot from Nebra"
  wget -q --show-progress https://snapshots-wtf.sensecapmx.cloud/snap-1378103 -O /tmp/snap-1378103
else
  modified=`stat -c %Y $filepath`
  now=`date +%s`
  longago=`expr $now - $modified`
  longagominutes=`expr $longago / 60`
  #NUM_SECS=`expr $HOW_LONG % 60`
  echo "Up-to-date snapshot already downloaded $longagominutes minutes ago"
  sleep 5; # Wait until the miner is fully functional
fi
echo -n "Pausing sync... "
sudo docker exec $minername sh -c 'export RELX_RPC_TIMEOUT=600; miner repair sync_pause'
echo -n "Cancelling pending sync... "
sudo docker exec $minername sh -c 'export RELX_RPC_TIMEOUT=600;miner repair sync_cancel'
echo "Start loading snap-1378103 at `date +%H:%M`. This can take up to 60 minutes"
sudo rm -f /home/pi/hnt/miner/snap/snap-*
sudo cp /tmp/snap-1378103 /home/pi/hnt/miner/snap/snap-1378103
> /tmp/load_result
now=`date +%s`
((sudo docker exec $minername sh -c "export RELX_RPC_TIMEOUT=3600; miner snapshot load /var/data/snap/snap-1378103" > /tmp/load_result) > /dev/null 2>&1 &)
#(((sleep 30 && echo "ok") > /tmp/load_result) > /dev/null 2>&1 &)
while :
do
    result=$(cat /tmp/load_result);
    if [ "$result" = "ok" ]; then
       modified=`stat -c %Y /tmp/load_result`
       longago=`expr $modified - $now`
       longagominutes=`expr $longago / 60`
       echo " "
       echo "Snapshot loaded in $longagominutes minutes"
       sudo rm -f /home/pi/hnt/miner/snap/snap-1378103
       rm /tmp/load_result
       echo -n "Resuming sync... "
       sudo docker exec $minername sh -c 'export RELX_RPC_TIMEOUT=600;miner repair sync_resume'
       echo "Done!"
       break;
    elif [ "$result" = "" ];then
       echo -n "."
    else
       echo "Error: Snapshot could not be loaded. Try again"
       break;
    fi
    sleep 120
done
