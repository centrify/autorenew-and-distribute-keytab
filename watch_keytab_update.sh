#!/bin/sh

WATCH_HOST=$1
WATCH_FILE=$2
if [ $# -gt 2 ]; then
	LOCAL_HASH="forceChange"
	echo test simulating ... remote file changed
fi
WATCH_KEY=$(basename $WATCH_FILE)
RANDOM_WAIT_RANGE="0-15"

get_file () {
        echo ... getting $1 =\> $2 from $WATCH_HOST
        scp $WATCH_HOST:$1 $2
	echo ... done
}

wait_a_while () {
	W=$(shuf -i $RANDOM_WAIT_RANGE -n 1)
	echo ... waiting $W seconds ...
	sleep $W
}

#----- main 

#echo "get [$ETCD_WATCH_EVENT_TYPE]"
#echo "get [$ETCD_WATCH_KEY]"
#echo "get [$ETCD_WATCH_VALUE]"

if [ "$LOCAL_HASH" = ""  -a -f ${WATCH_FILE} ]; then
	LOCAL_HASH=$(md5sum ${WATCH_FILE} | cut -f1 -d" ")
fi
#echo "LOCAL HASH " $LOCAL_HASH

if eval [ $ETCD_WATCH_VALUE != $LOCAL_HASH ]; then
	wait_a_while
	get_file ${WATCH_FILE} ${WATCH_FILE}
else
	echo "${WATCH_FILE} hash match - not changed. skip." 
fi

