#!/usr/bin/env sh

# This script is aimed to be POSIX-compliant and style consistent with help of these tools:
# - https://github.com/koalaman/shellcheck
# - https://github.com/openstack-dev/bashate

trap "exit 1" TERM
TOP_PID=$$

KUBECTL_ARGS=""
WIAT_TIME=2 # seconds
DEBUG=0

usage() {
cat <<EOF
This script waits until a job, pod or service enter ready state. 

${0##*/} job [<job name> | -l<kubectl selector>]
${0##*/} pod [<pod name> | -l<kubectl selector>]
${0##*/} service [<service name> | -l<kubectl selector>]

Examples:
Wait for all pods with with a following label to enter 'Ready' state:
${0##*/} pod -lapp=develop-volume-gluster-krakow

Wait for all the pods in that job to have a 'Succeeded' state:
${0##*/} job develop-volume-s3-krakow-init

Wait for all the pods in that job to have a 'Succeeded' state:
${0##*/} job develop-volume-s3-krakow-init

Wait for all selected pods to enter the 'Ready' state:
${0##*/} pod -l"release in (develop), chart notin (cross-support-job-3p)"

Wait for all selected pods to enter the 'Ready' state:
${0##*/} pod -l"release in (develop), chart notin (cross-support-job-3p)"
EOF
exit 1
}

# Job or set of pods is considered ready if all of the are ready
# example output with 3 pods, where 2 are not ready would be: "false false"
get_pod_state() {
    get_pod_state_name="$1"
    get_pod_state_flags="$2"
    get_pod_state_output1=$(kubectl get pods "$get_pod_state_name" $get_pod_state_flags $KUBECTL_ARGS -o go-template='{{- if .items -}}
  {{- if gt (len .items) 0}}
    {{- range .items -}}
      {{- range .status.conditions -}}
        {{- if and (eq .type "Ready") (eq .status "False") -}}
        {{ .status }}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- else -}}
    {{- range .status.conditions -}}
        {{- if and (eq .type "Ready") (eq .status "False") -}}
        {{ .status }}
        {{- end -}}
    {{- end -}}
  {{- end -}}
{{- else -}}
  {{- printf "No resources found.\n" -}}
{{- end -}}'  2>&1)
    if [ $? -ne 0 ]; then
        if expr match "$get_pod_state_output1" '\(.*not found$\)' 1>/dev/null ; then
            echo "No pods found, waiting for them to be created..." >&2
            echo "$get_pod_state_output1" >&2
        else
            echo "$get_pod_state_output1" >&2
            kill -s TERM $TOP_PID
        fi
    elif [ $DEBUG -ge 2 ]; then
        echo "$get_pod_state_output1" >&2
    fi
    get_pod_state_output2=$(printf "%s" "$get_pod_state_output1" | xargs )
    if [ $DEBUG -ge 1 ]; then
        echo "$get_pod_state_output2" >&2
    fi
    echo "$get_pod_state_output2"
}

# Service or set of service is considered ready if all of the pods matched my service selector are considered ready
# example output with 2 services each matching a single pod would be: "falsefalse"
get_service_state() {
    get_service_state_name="$1"
    get_service_state_selectors=$(kubectl get service "$get_service_state_name" $KUBECTL_ARGS -ojson 2>&1 | jq -cr 'if . | has("items") then .items[] else . end | [ .spec.selector | to_entries[] | "-l\(.key)=\(.value)" ] | join(",") ')
    get_service_state_states=""
    for get_service_state_selector in $get_service_state_selectors ; do
        get_service_state_selector=$(echo "$get_service_state_selector" | tr ',' ' ')
        get_service_state_state=$(get_pod_state "" "$get_service_state_selector")
        get_service_state_states="${get_service_state_states}${get_service_state_state}" ;
    done
    echo "$get_service_state_states"
}

# Job or set of jobs is considered ready if all of them succeeded at least once
# example output with 2 still running jobs would be "0 0"
# this function considers the line:
# Pods Statuses:	0 Running / 1 Succeeded / 0 Failed
# in a 'kubectl describe' job output.
get_job_state() {
    get_job_state_name="$1"
    get_job_state_output=$(kubectl describe jobs $get_job_state_name $KUBECTL_ARGS 2>&1)
    if [ $? -ne 0 ]; then
        echo "$get_job_state_output" >&2
        kill -s TERM $TOP_PID
    elif [ $DEBUG -ge 2 ]; then
        echo "$get_job_state_output" >&2
    fi
    if [ "$get_job_state_output" = "" ]; then
        echo "wait_for.sh: No jobs found!" >&2
        kill -s TERM $TOP_PID
    fi
    get_job_state_output1=$(printf "%s" "$get_job_state_output" | sed -nr 's#.*/ (0+) .*/.*#\1#p' 2>&1)
    if [ $? -ne 0 ]; then
        echo "$get_job_state_output" >&2
        echo "$get_job_state_output1" >&2
        kill -s TERM $TOP_PID
    elif [ $DEBUG -ge 2 ]; then
        echo "$get_job_state_output1" >&2
    fi
    get_job_state_output2=$(printf "%s" "$get_job_state_output1" | xargs )
    if [ $DEBUG -ge 1 ]; then
        echo "$get_job_state_output2" >&2
    fi
    echo "$get_job_state_output2"
}

wait_for_service() {
    wait_for_service_name="$1"
    while [ "$(get_service_state "$wait_for_service_name")" != "" ] ; do
        wait_for "service" "$wait_for_service_name"
    done
    ready "service" "$wait_for_service_name"
}

wait_for_pod() {
    wait_for_pod_name="$1"
    while [ "$(get_pod_state "$wait_for_pod_name")" != "" ] ; do
        wait_for "pod" "$wait_for_pod_name"
    done
    ready "pod" "$wait_for_pod_name"
}

wait_for_job() {
    wait_for_job_name="$1"
    while [ "$(get_job_state "$wait_for_job_name")" != "" ] ; do
        wait_for "job" "$wait_for_job_name"
    done
    ready "job" "$wait_for_job_name"
}

wait_for() {
    wait_for_resource="$1"
    wait_for_name="$2"
    echo "Waiting for $wait_for_resource $wait_for_name $KUBECTL_ARGS..."
    sleep $WIAT_TIME
}

ready() {
    printf "%s %s %s is ready." "$1" "$2" "$KUBECTL_ARGS"
}

main() {
    if [ $# -eq 0 ]; then
        usage
    fi

    main_name=""
    main_resouce=""

    case $1 in
        pod)
            main_resouce="pod"
            main_name="$2"
            shift
            shift
            ;;
        service)
            main_resouce="service"
            main_name="$2"
            shift
            shift
            ;;
        job)
            main_resouce="job"
            main_name="$2"
            shift
            shift
            ;;
        *)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            exit 1
            ;;
    esac

    KUBECTL_ARGS="${*}"

    case $main_resouce in
        pod)
            wait_for_pod "$main_name"
            ;;
        job)
            wait_for_job "$main_name"
            ;;
        service)
            wait_for_service "$main_name"
            ;;
    esac

    exit 0
}

main "$@"
