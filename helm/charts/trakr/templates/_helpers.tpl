{{- define "trakr.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "trakr.fullname" -}}
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

{{- define "trakr.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "trakr.labels" -}}
helm.sh/chart: {{ include "trakr.chart" . }}
{{ include "trakr.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "trakr.selectorLabels" -}}
app.kubernetes.io/name: {{ include "trakr.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "trakr.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "trakr.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "trakr.postgresql.fullname" -}}
{{- printf "%s-postgresql" (include "trakr.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "trakr.postgresql.secretName" -}}
{{- if .Values.postgresql.auth.existingSecret }}
{{- .Values.postgresql.auth.existingSecret }}
{{- else }}
{{- include "trakr.postgresql.fullname" . }}
{{- end }}
{{- end }}

{{- define "trakr.postgresql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "trakr.postgresql.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "trakr.postgresql.labels" -}}
helm.sh/chart: {{ include "trakr.chart" . }}
{{ include "trakr.postgresql.selectorLabels" . }}
app.kubernetes.io/component: postgresql
app.kubernetes.io/version: {{ .Values.postgresql.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "trakr.pgadmin.fullname" -}}
{{- printf "%s-pgadmin" (include "trakr.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "trakr.pgadmin.secretName" -}}
{{- if .Values.pgadmin.auth.existingSecret }}
{{- .Values.pgadmin.auth.existingSecret }}
{{- else }}
{{- include "trakr.pgadmin.fullname" . }}
{{- end }}
{{- end }}

{{- define "trakr.pgadmin.selectorLabels" -}}
app.kubernetes.io/name: {{ include "trakr.pgadmin.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "trakr.pgadmin.labels" -}}
helm.sh/chart: {{ include "trakr.chart" . }}
{{ include "trakr.pgadmin.selectorLabels" . }}
app.kubernetes.io/component: pgadmin
app.kubernetes.io/version: {{ .Values.pgadmin.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
