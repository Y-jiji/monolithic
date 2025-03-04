export GTPIDFILE='/tmp/openconnect-gt.pid'

gt-vpn() {
    if [[ $1 == 'up' && ! -f $GTPIDFILE ]]; then
        openconnect -Sb -s "ocproxy -D 1080"    \
            --protocol=gp vpn.gatech.edu        \
            --pid-file "/tmp/openconnect-gt.pid"
    elif [[ $1 == 'down' ]]; then
        kill -9 $(cat $PIDFILE)
    fi
}

gt() {
    local c=$1
    shift 1
    if [[ $c == 'ssh' ]]; then
        ssh -o "ProxyCommand=nc -X 5 -x 127.0.0.1:1080 %h %p" $@
    elif [[ $c == 'vpn' ]]; then
        gt-vpn $@
    fi
}

