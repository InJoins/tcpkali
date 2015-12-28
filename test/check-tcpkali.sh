#!/bin/sh

set -e

if [ -z "${TCPKALI}" ]; then
    echo "WARNING: Use \`make check\` instead of running $0 directly."
    TCPKALI=../src/tcpkali
fi

PORT=1230

check() {
    local testno="$1"
    local togrep="$2"
    shift 2

    PORT=$(($PORT+1))
    local rest_opts="-T1s --source-ip 127.1 -l${PORT} 127.1:${PORT}"
    echo "Test ${testno}.srcip: $* ${rest_opts}" >&2
    $@ ${rest_opts} | egrep "$togrep"
    PORT=$(($PORT+1))
    local rest_opts="-T1s -l${PORT} 127.1:${PORT}"
    echo "Test ${testno}.autoip: $* ${rest_opts}" >&2
    $@ ${rest_opts} | egrep "$togrep"
}

check_output() {
    local testno="$1"
    local togrep="$2"
    local invert=false
    shift 2

    if [ $(echo "$togrep" | cut -f1 -d' ') = "-v" ]; then
        invert=true
        togrep=$(echo "$togrep" | cut -f2- -d' ')
    fi

    PORT=$(($PORT+1))
    local rest_opts="-T1s -l${PORT} 127.1:${PORT} --dump-one-out"
    echo "Test ${testno}: $* ${rest_opts}" >&2
    local n=$($@ ${rest_opts} 2>&1 | sed -E '/^Out/!d; s/[^:]+: \[([^]]*)\]/\1/' | egrep "$togrep" | grep -c .)
    if [ "$n" -ne 0 -a "$invert" = "true" ]; then
        echo "ERROR: $togrep yields $n results"
        return 1
    fi
    if [ "$n" -eq 0 -a "$invert" = "false" ]; then
        echo "ERROR: $togrep yields $n results"
        return 1
    fi
}

check 1 "." ${TCPKALI} --connections=20 --duration=1
check 2 "." ${TCPKALI} --connections=10 --duration=1 -m Z
check 3 "." ${TCPKALI} -c10 --message Z --message-rate=2
check 4 "." ${TCPKALI} -c10 -m Z --channel-bandwidth-upstream=10kbps

check 5 "Total data sent:[ ]+149 bytes"     ${TCPKALI} --ws
check 6 "Total data received:[ ]+278 bytes" ${TCPKALI} --ws
check 7 "Total data sent:[ ]+158 bytes"     ${TCPKALI} --ws --first-message ABC
check 8 "Total data received:[ ]+287 bytes" ${TCPKALI} --ws --first-message ABC

check 9 "." ${TCPKALI} --ws --message ABC
check 10 "." ${TCPKALI} --ws --first-message ABC --message foo

check 11 "latency at percentiles.*50.0/100.0" ${TCPKALI} --latency-connect --latency-first-byte --latency-percentiles 50,100
check 12 "50.0/100.0" ${TCPKALI} --latency-connect --latency-first-byte --latency-percentiles 50/100
check 13 "50.0/100.0" ${TCPKALI} --latency-connect --latency-first-byte --latency-percentiles 50 --latency-percentiles 100

# Smooth test with 20 messages per second (MPS)
check_output 14 "^432$" ${TCPKALI} -r20 -m432
check_output 15 "-v 324" ${TCPKALI} -r20 -m432

# Smooth test with 2kMPS
check_output 16 "^432432" ${TCPKALI} -r2000 -m432
check_output 17 "-v ^432$" ${TCPKALI} -r2000 -m432
check_output 18 "-v ^432432432432" ${TCPKALI} -r2000 -m432

# Smooth test with 15kMPS
check_output 19 "-v ^(432){1,3}$" ${TCPKALI} -r15k -m432
