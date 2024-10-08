#!/bin/bash

# This script requires the hey tool
# https://github.com/rakyll/hey

URL=$1
echo "Application address: $1"

for i in $(seq 1 5);
do
    DURATION=15
    CONCURRENT_WORKERS=$((7*$i))
    RATE_LIMIT_PER_SEC_PER_WORKER=$((6*$i))
    echo "Sending `expr $DURATION \* $CONCURRENT_WORKERS \* $RATE_LIMIT_PER_SEC_PER_WORKER` requests over $DURATION seconds"
    hey -z "$DURATION"s -c $CONCURRENT_WORKERS -q $RATE_LIMIT_PER_SEC_PER_WORKER -m GET $URL > /dev/null

    SLEEP=7
    echo "Waiting $SLEEP seconds..."
    sleep $SLEEP
done