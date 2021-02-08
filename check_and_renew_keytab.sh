#!/bin/sh

KEYTAB="/var/centrify/tmp/xxx.keytab"
TOPIC=$(basename $KEYTAB)
KEYPRINC="xxx"
ETCD_HOME="/usr/local/etcd-v3.4.14-linux-amd64/"
MYCA=/var/centrify/net/certs/trust_0469FAEACCACDB52BA6F73ED8176100FD34A7A36.cert
MYCERT=/var/centrify/net/certs/auto_CentrifyW2008EntWorkstationAuthenticationRSASHA256.cert
MYKEY=/var/centrify/net/certs/auto_CentrifyW2008EntWorkstationAuthenticationRSASHA256.key
ETCD_HOST="leo-u1804-s64.voyager.test"
KEYTAB_AGE_LIMIT=28

get_keytab_date() {
	W=$(klist -kt $KEYTAB | awk -e "\$1 ~ /[[:digit:]]+/ {print \$2 OFS \$1}" | sort -n -r -k 2 | head -1 | cut -f1 -d" ")
#	echo $W
}

# ----- main

if [ $# -gt 0 ]; then
	TEST_DATE=$1
	echo test simulating ... today is ${TEST_DATE} - to force adkeytab changing password
fi
if [ $# -gt 1 ]; then
	TEST_ADKEYTAB="echo test simulating ... "
fi

get_keytab_date

# get keytab age 
python3 - $W $TEST_DATE <<EOF
import sys
import datetime
import dateutil.parser

#print(len(sys.argv))
if len(sys.argv) < 2:
    print(f"usage: {sys.argv[0]} date1 [date2]")
    print("date2 default to today")
    exit(-1)
elif len(sys.argv) > 2:
    date2 = dateutil.parser.parse(sys.argv[2])
else:
    date2 = datetime.datetime.now()

date1 = dateutil.parser.parse(sys.argv[1])

#print(date1)
#print(date2)
w = date2 - date1
#print(w)
exit(w.days)
EOF
RD=$?
#echo $RD

if [ $RD -gt $KEYTAB_AGE_LIMIT ] ; then
	kinit -kt $KEYTAB $KEYPRINC
#	klist
	$TEST_ADKEYTAB adkeytab -C -V -K ${KEYTAB} ${KEYPRINC}
	RC=$?
	if [ $RC -eq 0 ]; then
		$ETCD_HOME/etcdctl --cacert $MYCA --cert=$MYCERT --key=$MYKEY --endpoints=${ETCD_HOST}:2379 \
		       	put ${TOPIC}\
			$(md5sum $KEYTAB | cut -f1 -d" ")
	fi
else 
	echo "${KEYTAB} last changed on ${W} - within age limit ${KEYTAB_AGE_LIMIT}. skip action."
fi
