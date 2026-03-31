{{- define "common.labels" -}}
app.kubernetes.io/managed-by: gitops-platform
{{- end }}

{{- define "sanitize.name" -}}
{{- . | lower | replace "_" "-" | replace " " "-" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "rolebinding.name" -}}
{{- $sanitizedGroup := include "sanitize.name" .group }}
{{- printf "%s-%s" $sanitizedGroup .namespace | trunc 253 | trimSuffix "-" }}
{{- end }}

{{- define "clusterrolebinding.name" -}}
{{- $sanitizedGroup := include "sanitize.name" .group }}
{{- printf "crb-%s-%s" $sanitizedGroup .namespace | trunc 253 | trimSuffix "-" }}
{{- end }}
