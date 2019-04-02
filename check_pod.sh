#!/bin/bash

kubectl get pods -o go-template='
{{- define "checkStatus" -}}
    {{- $rootStatus := .status }}
    {{- if (not .status.conditions) }}
        {{- printf "no .status.conditions yet\n" -}}
    {{- else }}
        {{- range .status.conditions -}}
            {{- if (not .status) -}}
                {{- printf "no .status.conditions.status yet\n" -}}
            {{- else if (eq .status "False") -}}
                {{- printf "type status reason: %s %s %s\n" .type .status .reason -}}
            {{- end -}}
        {{- end -}}
    {{- end -}}
{{- end -}}
{{- if .items -}}
    {{- range .items -}}
      {{ template "checkStatus" . }}
    {{- end -}}
{{- else -}}
    {{ template "checkStatus" . }}
{{- end -}}' -n pryon -l app=d2d-app-ps