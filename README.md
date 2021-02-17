# autorenew-and-distribute-keytab
automatically renew service account keytab (using adkeytab), and distribute to multiple other hosts 

# motivation
customers find the adkeytab utility useful to generate krb5.keytab for service account(s) that may be used for authentication purpose (in place of password) for applications like Hadoop, MongoDB, Oracle, etc. 

the problems remaining are
* change the password at interval
* distribute the new keytab to other hosts in the same cluster

# summary of solution
this demo uses [etcd](https://etcd.io) as the centerpiece of change notification.

see default configuration `/etc/etcd/my.etcd.yml`.
it is secured by TLS using the CA, certificate and private key generated by adclient auto-enrollment feature.
note, the certificate template should have ...
>            X509v3 Extended Key Usage:
>               TLS Web Client Authentication, TLS Web Server Authentication
etcd can be set up in systemd to automatically start on host startup.

## on hostA
this is where we generate and maintain the master copy of xxx.keytab (principal: xxx).
this is also where etcd runs.
the idea behind it is because other client hosts have to be able to reach this host to scp the updated xxx.keytab anyway.

this is where you will run `check_and_renewkeytab.sh` - likely in crontab, once a day.
it will read xxx.keytab to get latest KVNO and work out the days delta to today.
if over the default limit of 28 days, it will invoke adkeytab to change password, and update xxx.keytab with the new KVNO.
it will then `put` the etcd key (xxx.keytab) with value of md5sum of the new xxx.keytab.

* note the key-value pair will persists over etcd restart.
* you can modify it to use sha256sum if you like (both sides).

## on hostB
these are the client hosts that will connect to etcd to ___watch___ for changes, 
and run `scp` to hostA to get the updated the xxx.keytab.

hostB gets the notification, check md5sum to see if it indeed changed, and then proceed to use `scp` to get the updated xxx.keytab.
to avoid stampeding, there is a built-in radom delay of up to 15 seconds.

* client side `watch_keytab.sh` on startup will check to make sure if has initial copy of xxx.keytab, and the etcdctl CLI that it needs.
* `watch_keytab_update.sh` is invoked from within watch_keytab.sh.
* watch_keytab.sh runs in infinite loop ... use ctl-c to break out.
it is intended to be setup as systemd service to be started on system startup as well. 

# other notes
* `check_and_renew_keytab.sh` embeds a python call. it will import module `dateutil`. do `pip3 install python-dateutil` to get it
* regarding xxx.keytab. on AD, check to make sure service account "xxx" has permission to allow for `change password` and `reset password` by `SELF`.
* regarding the private key (auto_xxx.key) used by the shell scripts and etcd, make sure it is readable by the invocation process (`setfacl`). by default, it is only readable by root.

# testing
* `check_and_renew_keytab.sh` allows parameter "mm/dd/yy" to simulate a future date. otherwise, it will only initiate change after 28 days.
* `check_and_renew_keytab.sh` allows 2nd parameter (any string) to simulate invocation adkeytab to change password.
* `watch_keytab.sh` allows for any parameter (any string) to simulate remote file changed (thus to invoke scp).
