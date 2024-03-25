#!/bin/bash
# Export last 10 seconds of Unifi Admin activity logs to file in JSON format.

## System defaults
DB="ace"
DB_port=27117
DB_host="localhost"
DB_collection="admin_activity_log"
AA_log_dir="/var/log/unifi_admin_activity/"
AA_log_file="$AA_log_dir/unifi_admin_activity.log"

## Mongo query variables
BatchSize=2000
timespan=10

# Test if log folder exists and if the file is writeable
if [ ! -d "$AA_log_dir" ]; then
  echo "ERROR: $AA_log_dir does not exist."
  if mkdir "$AA_log_dir"; then
    echo "Log folder created: $AA_log_dir"
  else
    echo "ERROR: Failed to create: $AA_log_dir"
    exit 0
  fi
elif [ ! -w "$AA_log_dir" ]; then
  echo "ERROR: Can't write to log folder, please fix write permissions for user `whoami` on: $AA_log_dir"
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
  mongo $DB_host:$DB_port/$DB --quiet --eval 'DBQuery.shellBatchSize = '"$BatchSize"'; db.'"$DB_collection"'.find({"time": {"$gt": '"$time"'}},{"_id":0})' | \
    sed 's/\(NumberLong([[:punct:]]\?\)\([[:digit:]]*\)\([[:punct:]]\?)\)/\"\2\"/' >> "$AA_log_file"
}

function last_time {
  # Read the last logged line from the log file.
  last_log=$(tail -n1 "$AA_log_file" | sed 's/\(NumberLong([[:punct:]]\?\)\([[:digit:]]*\)\([[:punct:]]\?)\)/\"\2\"/' | jq -r .time)
  # If the log file is empty then read the last $timespan seconds.
  [ -z "$last_log" ] && echo $(date --date "-$timespan sec" +%s)000 || echo "$last_log"
}

time="$(last_time)"
while rwdata
do
  time="$(last_time)"
  sleep $timespan
done
