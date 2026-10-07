{{/*
Reusable named templates. Call them with:  {{ include "notes-chart.<name>" . }}
*/}}

{{/* Chart name + version, e.g. notes-chart-0.1.0 */}}
{{- define "notes-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Labels used by the Service selector and Deployment matchLabels (must stay stable) */}}
{{- define "notes-chart.selectorLabels" -}}
app: {{ .Release.Name }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Full label set for every object */}}
{{- define "notes-chart.labels" -}}
helm.sh/chart: {{ include "notes-chart.chart" . }}
{{ include "notes-chart.selectorLabels" . }}
environment: {{ .Values.app.environment }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* image reference; fails rendering early if repository is empty */}}
{{- define "notes-chart.image" -}}
{{- $repo := required "image.repository is required" .Values.image.repository -}}
{{- printf "%s:%s" $repo (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}
