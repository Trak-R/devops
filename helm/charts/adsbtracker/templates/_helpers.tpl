{{/*
Expand the chart name.
*/}}
{{- define "adsbtracker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified application name.
*/}}
{{- define "adsbtracker.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "adsbtracker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "adsbtracker.labels" -}}
helm.sh/chart: {{ include "adsbtracker.chart" . }}
{{ include "adsbtracker.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "adsbtracker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "adsbtracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "adsbtracker.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "adsbtracker.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "adsbtracker.secretName" -}}
{{- default (include "adsbtracker.fullname" .) .Values.existingSecret }}
{{- end }}

{{/*
repository and tag are required. Do not default to a Docker Hub latest tag.
*/}}
{{- define "adsbtracker.image" -}}
{{- $repository := required "image.repository is required. Build docker/Dockerfile.source and push it to your registry." .Values.image.repository -}}
{{- $tag := required "image.tag is required. Pin the tag of the image you published." .Values.image.tag -}}
{{- printf "%s:%s" $repository $tag -}}
{{- end }}

{{- define "adsbtracker.dataMount" -}}
{{- trimSuffix "/" .Values.persistence.data.mountPath }}
{{- end }}

{{- define "adsbtracker.profilesMount" -}}
{{- trimSuffix "/" .Values.persistence.profiles.mountPath }}
{{- end }}
