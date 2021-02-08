#!/bin/sh

WATCH_FILE="/var/centrify/tmp/xxx.keytab"
TOPIC=$(basename $WATCH_FILE)

WATCH_HOST="leo-u1804-s64.voyager.test"
MYCA=/var/centrify/net/certs/trust_0469FAEACCACDB52BA6F73ED8176100FD34A7A36.cert
MYCERT=/var/centrify/net/certs/auto_CentrifyW2008EntWorkstationAuthenticationRSASHA256.cert
MYKEY=/var/centrify/net/certs/auto_CentrifyW2008EntWorkstationAuthenticationRSASHA256.key
ETCDCTL=/usr/local/etcd-v3.4.14-linux-amd64/etcdctl
LOCAL_ETCDCTL=/usr/local/bin/etcdctl
RETRY_INTERVAL=60

get_file () {
	echo ... getting $1 =\> $2 from $WATCH_HOST
	scp $WATCH_HOST:$1 $2
}

# ----- main 

if [ $# -gt 0 ]; then
	FORCE_UPDATE_ON_WATCH=yes
	echo test simulating ... will force file update on watch
fi
if [ ! -f ${WATCH_FILE} ]; then
	get_file $WATCH_FILE $WATCH_FILE
fi

if [ ! -x ${LOCAL_ETCDCTL} ]; then
	get_file $ETCDCTL $LOCAL_ETCDCTL
	chmod a+x $LOCAL_ETCDCTL
fi

# infinite loop unitl interrupted (built-in retry)
while true; do
	echo do startup check of ${WATCH_FILE} on ${WATCH_HOST} ... 
	WORK_HASH=$($LOCAL_ETCDCTL --cacert=$MYCA --cert=$MYCERT --key=$MYKEY --endpoints=$WATCH_HOST:2379 get --print-value-only $TOPIC)
	ETCD_WATCH_VALUE=${WORK_HASH} ./watch_keytab_update.sh ${WATCH_HOST} ${WATCH_FILE}

	echo start watching ${WATCH_HOST} for ${WATCH_FILE} ...
	$LOCAL_ETCDCTL --cacert=$MYCA --cert=$MYCERT --key=$MYKEY --endpoints=$WATCH_HOST:2379 watch $TOPIC -- ./watch_keytab_update.sh ${WATCH_HOST} ${WATCH_FILE} ${FORCE_UPDATE_ON_WATCH}

	echo watch cycle terminated ... retry in ${RETRY_INTERVAL} seconds
	sleep $RETRY_INTERVAL
done
