#!/usr/bin/env sh

# This script is aimed to be POSIX-compliant and style consistent with help of these tools:
# - https://github.com/koalaman/shellcheck
# - https://github.com/openstack-dev/bashate

trap "exit 1" TERM
TOP_PID=$$

KUBECTL_ARGS=""
WAIT_TIME="${WAIT_TIME:-2}" # seconds
DEBUG="${DEBUG:-0}"
TREAT_ERRORS_AS_READY=0

usage() {
cat <<EOF
This script waits until a job, pod or service enter ready state. 

${0##*/} job [<job name> | -l<kubectl selector>]
${0##*/} pod [<pod name> | -l<kubectl selector>]
${0##*/} service [<service name> | -l<kubectl selector>]

Examples:
Wait for all pods with with a following label to enter 'Ready' state:
${0##*/} pod -lapp=develop-volume-gluster-krakow

Wait for all pods with with a following label to enter 'Ready' or 'Error' state:
${0##*/} pod-we -lapp=develop-volume-gluster-krakow

Wait for all the pods in that job to have a 'Succeeded' state:
${0##*/} job develop-volume-s3-krakow-init

Wait for all the pods in that job to have a 'Succeeded' or 'Failed' state:
${0##*/} job-we develop-volume-s3-krakow-init

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
    get_pod_state_output1=$(kubectl get pods "$get_pod_state_name" $get_pod_state_flags $KUBECTL_ARGS -o go-template='
{{- define "checkStatus" -}}
  {{- $rootStatus := .status }}
  {{- range .status.conditions -}}
      {{- if and (eq .type "Ready") (eq .status "False") -}}
      {{- if .reason -}}
        {{- if ne .reason "PodCompleted" -}}
          {{ .status }}
          {{- range $rootStatus.containerStatuses -}}
            {{- if .state.terminated.reason -}}
            :{{ .state.terminated.reason }}
            {{- end -}}
          {{- end -}}
        {{- end -}}
      {{- else -}}
        {{ .status }}
      {{- end -}}
      {{- end -}}
  {{- else -}}
    {{- printf "No resources found.\n" -}}
  {{- end -}}
{{- end -}}
{{- if .items -}}
    {{- range .items -}}
      {{ template "checkStatus" . }}
    {{- end -}}
{{- else -}}
    {{ template "checkStatus" . }}
{{- end -}}' 2>&1)
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
    if [ $TREAT_ERRORS_AS_READY -eq 1 ]; then
        get_pod_state_output1=$(printf "%s" "$get_pod_state_output1" | sed 's/False:Error//g' )
        if [ $DEBUG -ge 1 ]; then
            echo "$get_pod_state_output1" >&2
        fi
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
    get_job_state_output=$(kubectl describe jobs "$get_job_state_name" $KUBECTL_ARGS 2>&1)
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
    get_job_state_output1=$(printf "%s" "$get_job_state_output" | sed -nr 's#.*:[[:blank:]]+([[:digit:]]+) [[:alpha:]]+ / ([[:digit:]]+) [[:alpha:]]+ / ([[:digit:]]+) [[:alpha:]]+.*#\1:\2:\3#p' 2>&1)
    if [ $? -ne 0 ]; then
        echo "$get_job_state_output" >&2
        echo "$get_job_state_output1" >&2
        kill -s TERM $TOP_PID
    elif [ $DEBUG -ge 2 ]; then
        echo "$get_job_state_output1" >&2
    fi

    # Extract number of <running>:<succeeded>:<failed>
    get_job_state_output1=$(printf "%s" "$get_job_state_output" | sed -nr 's#.*:[[:blank:]]+([[:digit:]]+) [[:alpha:]]+ / ([[:digit:]]+) [[:alpha:]]+ / ([[:digit:]]+) [[:alpha:]]+.*#\1:\2:\3#p' 2>&1)
    if [ $DEBUG -ge 1 ]; then
        echo "$get_job_state_output1" >&2
    fi
    
    # Map triplets of <running>:<succeeded>:<failed> to not ready (emit 0) state
    if [ $TREAT_ERRORS_AS_READY -eq 0 ]; then
        sed_reg='-e s/^[1-9]+:[[:digit:]]+:[[:digit:]]+$/1/p -e s/^0:0:[1-9]+$/1/p'
    else
        sed_reg='-e s/^[1-9]+:[[:digit:]]+:[[:digit:]]+$/1/p'
    fi
    
    get_job_state_output2=$(printf "%s" "$get_job_state_output1" | sed -nr $sed_reg 2>&1)
    if [ $DEBUG -ge 1 ]; then
        echo "$get_job_state_output2" >&2
    fi

    get_job_state_output3=$(printf "%s" "$get_job_state_output2" | xargs )
    if [ $DEBUG -ge 1 ]; then
        echo "$get_job_state_output3" >&2
    fi
    echo "$get_job_state_output3"
}

wait_for_resource() {
    wait_for_resource_type=$1
    wait_for_resource_descriptor="$2"
    while [ -n "$(get_${wait_for_resource_type}_state "$wait_for_resource_descriptor")" ] ; do
        print_KUBECTL_ARGS="$KUBECTL_ARGS"
        [ "$print_KUBECTL_ARGS" != "" ] && print_KUBECTL_ARGS=" $print_KUBECTL_ARGS"
        echo "Waiting for $wait_for_resource_type $wait_for_resource_descriptor${print_KUBECTL_ARGS}..."
        sleep "$WAIT_TIME"
    done
    ready "$wait_for_resource_type" "$wait_for_resource_descriptor"
}

ready() {
    print_KUBECTL_ARGS="$KUBECTL_ARGS"
    [ "$print_KUBECTL_ARGS" != "" ] && print_KUBECTL_ARGS=" $print_KUBECTL_ARGS"
    printf "[%s] %s %s%s is ready.\\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$1" "$2" "$print_KUBECTL_ARGS"
}

main() {
    if [ $# -lt 2 ]; then
        usage
    fi

    case "$1" in
        pod|service|job)
            main_resource=$1
            shift
            ;;
        pod-we|job-we)
            main_resource=${1%-we}
            TREAT_ERRORS_AS_READY=1
            shift
            ;;
        *)
            printf 'ERROR: Unknown resource type: %s\n' "$1" >&2
            exit 1
            ;;
    esac

    main_name="$1"
    shift

    KUBECTL_ARGS="${*}"

    wait_for_resource "$main_resource" "$main_name"

    exit 0
}

main "$@"
