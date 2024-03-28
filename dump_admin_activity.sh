#!/bin/bash
# Export last 10 seconds of Unifi Admin activity logs to file in JSON format.
# Author: Djerk Geurts <djerk@maizymoo.com>
# Source: https://github.com/dmgeurts/unifi_admin_activity_logs

## System defaults
DB="ace"
DB_port=27117
DB_host="localhost"
DB_collection="admin_activity_log"
AA_log_dir="/var/log/unifi_admin_activity/"
AA_log_file="$AA_log_dir/unifi_admin_activity.log"
service_user="unifi" # unifi suggested, but root or $(whoami) are also possibilities

## Mongo query variables
timespan=10
BatchSize=2000
mongo_opt=""
state="good"
jq_opt=""

# Test if mongo or mongosh are installed
if client="$(which mongosh)"; then
  echo "[$(date)] MongoDB Shell found."
elif client="$(which mongo)"; then
  echo "[$(date)] Old MongoDB client found, pre MongoDB 5.0"
  jq_opt="-s"
else
  echo "ERROR: No MongoDB Shell or client found."
  exit 0
fi

# Test if log folder exists and if the file is writeable
if [ ! -d "$AA_log_dir" ]; then
  echo "ERROR: $AA_log_dir does not exist."
  if mkdir "$AA_log_dir"; then
    echo "Log folder created: $AA_log_dir"
  # Try with sudo if it didn't work without
  elif sudo mkdir "$AA_log_dir"; then
    sudo chown $service_user:$service_user "$AA_log_dir"
  else
    echo "ERROR: Failed to create: $AA_log_dir"
    if [[ $EUID > 0 ]]; then
      echo "WARNING: Ensure user $(whoami) is a member of the syslog group or has sudo rights to create"
      echo "         the log folder. Alternatively, manually create $AA_log_dir"
    fi
    exit 0
  fi
elif [ ! -w "$AA_log_dir" ]; then
  echo "ERROR: Can't write to log folder, please fix write permissions for user $(whoami) on: $AA_log_dir"
  exit 0
elif [ ! -w "$AA_log_file" ]; then
  if [ ! -f "$AA_log_file" ]; then
    if touch "$AA_log_file"; then
      echo "Log file created: $AA_log_file"
    else
      echo "ERROR: Failed to create log file: $AA_log_file"
      exit 0
    fi
  #else
  #  echo "Log file exists and is writeable.
  fi
fi

function rwdata {
  if nc -z $DB_host $DB_port; then
    output=$("$client" $DB_host:$DB_port/$DB --quiet --eval 'db.'"$DB_collection"'.find({"time": {"$gt": '"$time"'}},{"_id":0}).toArray()' | \
      sed 's/\(\(Number\)\?Long([[:punct:]]\{1,2\}\)\([[:digit:]]*\)\([[:punct:]]\{1,2\})\)/\3/' | \
      sed -r 's/\ ([a-zA-Z_]+):/\ "\1":/g' | sed "s/'/\"/g" | jq "$jq_opt" -c 'sort_by(.time) | .[]')
      # "NumberLong" needs to be removed.
      # It can happen that MongoDB spits out the records in the wrong order, sorting by time avoids repeat reads of logged records.
      # Since mongosh the output is no longer properly quoted
    if [ ! -z "$output" ] && echo "$output" | jq -e >/dev/null 2>&1; then
      # Only write valid json to file
      echo "$output" >> "$AA_log_file"
      if [[ "$state" != "good" ]]; then
        echo "[$(date)] Admin Activity log entry read from MongoDB and written to file."
        state="good"
      fi
    elif [ ! -z "$output" ]; then
      # Log invalid JSON
      echo "[$(date)] Ignoring invalid JSON: $output"
      state="bad"
    fi
  else
    # Log missing MongoDB port
    echo "[$(date)] No service found listening on: $DB_host:$DB_port"
    state="bad"
  fi
}

function last_time {
  # Read the last logged line from the log file.
  last_log=$(tail -n1 "$AA_log_file" | sed 's/\(NumberLong([[:punct:]]\?\)\([[:digit:]]*\)\([[:punct:]]\?)\)/\"\2\"/' | jq -r .time)
  # If the log file is empty then read the last $timespan seconds.
  [ -z "$last_log" ] && echo $(date --date "-$timespan sec" +%s)000 || echo "$last_log"
}

while time="$(last_time)"
do
  rwdata
  sleep $timespan
done
