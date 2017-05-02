#!/bin/bash
# Ensure NetworkManager is stopped
# sudo service NetworkManager stop


# sets the wlan interface
wlan="wlan0"

# Download from online and store BSSID into array
# split into two commands so wget can complete download, otherwise array could end up as empty
wget -q --tries=10 --timeout=20 "https://www.dropbox.com/s/9jlaa0cs1sm12oo/whitelistedAP.txt?dl=1" -O whitelistedAP
fromWhitelistFile=$(cat whitelistedAP | tr "\n" " ")

declare -a whitelistedBSSIDArray
whitelistedBSSIDArray=($fromWhitelistFile)
echo "Whitelisted AP:" ${whitelistedBSSIDArray[*]}

# get bssid for mac 
#/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep "BSSID"

# get bssid for ubuntu
connectedAP=$(iwconfig $wlan | grep "Access Point" | awk '{print $6}')
echo "Connected to AP:" $connectedAP

# check if connected AP is in whitelist
echo "Checking if connected AP is whitelisted..."
if [[ " ${whitelistedBSSIDArray[@]} " =~ " ${connectedAP} " ]]; then
	notify-send "Connected AP in whitelist"
else
	# prompt user to disconnect
	notify-send "Connected AP not in whitelist"
	#xmessage -buttons Yes:0,No:1 -default Yes -center "Disconnect current connection and connect to a safe AP?"
	zenity --title "Unsafe Connection Detected" --question --text "Disconnect current connection and connect to a safe AP?"
	
	# if user choose to disconnect, scan for whitelisted AP to connect
	if [[ $? == 0 ]] ; then
		echo "Disconnecting..."
		iw dev $wlan disconnect
		sleep 3

		declare -a bssids
		declare -a essids
		ind=-1
		while read line; do
			case $line in
				Cell*)
					((ind++))
					bssids[$ind]=${line##* }
					#echo ${bssids[$ind]}
					;;
				ESSID*)
					essids[$ind]=${line##*:}
					#echo ${essids[$ind]}
					;;
			esac
		done < <(iwlist $wlan scan)

		# loops whitelisted AP to connect
		for ap in "${whitelistedBSSIDArray[@]}"; do
			if [[ " ${bssids[@]} " =~ " ${ap} " ]]; then
				echo "Whitelisted AP found: $ap"
				for ((i=0; i<${#bssids[*]}; i++)); do
					if [ "${bssids[$i]}" == "$ap" ] ; then
						echo "Connecting to ${essids[$i]} $ap..."
						iwconfig $wlan essid ${essids[$i]//\"} ap $ap
					fi
				done
			fi
		done

	fi
fi

