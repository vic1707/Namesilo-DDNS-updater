#!/bin/bash

for i in "$@"
do
  case $i in
    # optional
    -v|--verbose)
      VERBOSE=1
    ;;
  esac
done

## Enable function to kill the script
trap "exit 1" TERM
TOP_PID=$$

## Retreive environement variables from .env file
source $(dirname "${BASH_SOURCE[0]}")/.env

LOG_FILE=$(dirname "${BASH_SOURCE[0]}")/$LOG_FILE

## Fcts :
namesilo_update() {
  local ip_type=$1      # V4 or V6
  local record_type=$2  # A or AAAA
  local ttl=$3

  ## Retreive current external IP
  local IP_ADDRESS=$( curl -s -${ip_type: -1} https://ifconfig.co/ip )
  if [[ -z "$IP_ADDRESS" || "$IP_ADDRESS" == *"error"* ]] || [[ "$ip_type" == "V6" && ! "$IP_ADDRESS" =~ ":" ]]; then
    [[ $VERBOSE ]] && printf "IP$ip_type Address can't be determined"
    update_line_or_add_one "Address can't be determined"
    return 1
  fi

  [[ $VERBOSE ]] && printf "\
    Current IP: '$IP_ADDRESS'\n"

  ## Set save files
  local IP_FILE="./$DOMAIN/$ip_type-$DOMAIN-PubIP"
  local IP_TIME="./$DOMAIN/$ip_type-$DOMAIN-IPTime"
  ## Retreive old IP
  [[ -f $IP_FILE ]] && local KNOWN_IP=$(cat $IP_FILE) || local KNOWN_IP=

  [[ $VERBOSE ]] && printf "\
      Known IP: '$KNOW_IP'\n\n"

  ## Check if IP has changed
  if [[ "$IP_ADDRESS" != "$KNOWN_IP" ]]; then
    [[ $VERBOSE ]] && printf "    IP differs from known !\n\n"
    for HOST in "${HOSTS[@]}"; do
      # @ is the bare domain.  Dots are not required, but handle correctly in
      # case the user puts them in anyway.

      ## remove @ and . from HOST
      HOST=${HOST%@}
      HOST=${HOST%.}
      ## adding dot if there's an host
      local HOST_DOT="${HOST:+$HOST.}"
      ## Update current IP in file
      echo $IP_ADDRESS > $IP_FILE

      ## Retreive all records for the domain
      curl -s "https://www.namesilo.com/api/dnsListRecords?version=1&type=xml&key=$APIKEY&domain=$DOMAIN" > $RECORDS

      ## Extract record ID for the domain, ip_type and host
      local RECORD_ID=`xmllint --xpath "//namesilo/reply/resource_record/record_id[../host/text() = '$HOST_DOT$DOMAIN' ][../type = '$record_type' ]" $RECORDS 2>/dev/null`
      RECORD_ID=${RECORD_ID#*>}
      RECORD_ID=${RECORD_ID%<*}

      #if RECORD_ID is empty, then the record does not exist, so create it
      if [[ -z "$RECORD_ID" ]]; then
        [[ $VERBOSE ]] && printf "    No record found\n    Creating record for '$HOST_DOT$DOMAIN'\n"
        curl -s "https://www.namesilo.com/api/dnsAddRecord?version=1&type=xml&key=$APIKEY&domain=$DOMAIN&rrtype=$record_type&rrhost=$HOST&rrvalue=$IP_ADDRESS&rrttl=$ttl" > $RESPONSE
      else
        [[ $VERBOSE ]] && printf "    Record found\n    Updating record for '$HOST_DOT$DOMAIN'\n"
        [[ $VERBOSE ]] && printf "    IP on Namesilo: '$RECORD_VALUE'\n"
        ## Extract IP from Record
        local RECORD_VALUE=`xmllint --xpath "//namesilo/reply/resource_record/value[../record_id/text() = '$RECORD_ID' ]" $RECORDS`
        RECORD_VALUE=${RECORD_VALUE#*>}
        RECORD_VALUE=${RECORD_VALUE%<*}

        ## IP is already on Namesilo (will be executed on first run if you've set up the right IP)
        if [[ "$RECORD_VALUE" == "$IP_ADDRESS" ]]; then
          [[ $VERBOSE ]] && printf "IP Already on Namesilo !\n"
          date "+%s" > $IP_TIME
          continue
        else
          ## Update record
          curl -s "https://www.namesilo.com/api/dnsUpdateRecord?version=1&type=xml&key=$APIKEY&domain=$DOMAIN&rrid=$RECORD_ID&rrhost=$HOST&rrvalue=$IP_ADDRESS&rrttl=$ttl" > $RESPONSE
        fi
      fi
      ## Extract response code
      local RESPONSE_CODE=`xmllint --xpath "//namesilo/reply/code/text()" $RESPONSE`
      case $RESPONSE_CODE in
        300)
          ## Set update time
          date "+%s" > $IP_TIME
          printf "IP$ip_type : Operation success. Now '$HOST_DOT$DOMAIN' IP address is '$IP_ADDRESS'\n" >> $LOG_FILE
          ;;
        280)
          local ERROR_DETAILS=`xmllint --xpath "//namesilo/reply/detail/text()" $RESPONSE`
          printf "IP$ip_type : There has been an error with the content of the request, see below\n'$ERROR_DETAILS'\n\n\n" >> $LOG_FILE
          ## put the old IP back, so that the update will be tried next time
          echo $KNOWN_IP > $IP_FILE
          ;;
        *)
          ## put the old IP back, so that the update will be tried next time
          echo $KNOWN_IP > $IP_FILE
          printf "IP$ip_type : DDNS update failed code '$RESPONSE_CODE'!\n" >> $LOG_FILE
          ;;
      esac
    done
  else
    [[ $VERBOSE ]] && printf "Same IP as known!\n"
    update_line_or_add_one "Same IP as the saved one"
  fi
}

update_line_or_add_one() {
  local message=$1
  ## grab the last line of the log file that contains "IP$ip_type"
  local LAST_IP_CHANGE_LINE=$(grep "IP$ip_type" $LOG_FILE | tail -n 1)

  ## if the last line contains a date of format "%m-%d-%y | %H:%M:%S"
  if [[ $LAST_IP_CHANGE_LINE =~ [0-9]{2}-[0-9]{2}-[0-9]{2} ]]; then
    ## then edit that line
    ## no other choice than a tmp file since syntax is different between Mac and Linux
    sed -e "s/$LAST_IP_CHANGE_LINE/IP$ip_type : $(date +"%m-%d-%y | %H:%M:%S") - $message/" $LOG_FILE > $LOG_FILE.tmp
    cat $LOG_FILE.tmp > $LOG_FILE
    rm $LOG_FILE.tmp
  else
    printf "IP$ip_type : $(date +"%m-%d-%y | %H:%M:%S") - $message\n" >> $LOG_FILE
  fi
}
## End Fcts

[[ $VERBOSE ]] && printf "Starting Namesilo DDNS updater : '$(date)'\n\n"

for DOMAIN in "${DOMAINS[@]}"; do
  ## create $DOMAIN directory if it doesn't exist
  [[ ! -d $DOMAIN ]] && mkdir $DOMAIN

  ## Response from Namesilo
  RESPONSE="./$DOMAIN/namesilo_response-$DOMAIN.xml"
  RECORDS="./$DOMAIN/$DOMAIN.xml"

  [[ $VERBOSE ]] && printf "  ----  Updating $DOMAIN !  ----\n\n"
  if [[ $UPDATE_IP_V4 ]]; then
    [[ $VERBOSE ]] && printf "Updating IP V4 records\n\n"
    namesilo_update V4 A $IP_V4_TTL
  fi
  if [[ $UPDATE_IP_V6 ]]; then
    [[ $VERBOSE ]] && printf "\n\nUpdating IP V6 records\n\n"
    namesilo_update V6 AAAA $IP_V6_TTL
  fi

  ## to remove all created files
  rm $RESPONSE $RECORDS 2>/dev/null
done

[[ $VERBOSE ]] && printf "\n\nFinished Namesilo DDNS updater : '$(date)'\n"
exit 0
