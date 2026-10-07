{{- define "taskboard.name" -}}{{ .Chart.Name | trunc 63 | trimSuffix "-" }}{{- end }}

{{- define "taskboard.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}{{ .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else -}}{{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- end }}

{{- define "taskboard.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/name: {{ include "taskboard.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: taskboard
{{- end }}

{{/* selector labels for one component: include "taskboard.selectorLabels" (dict "ctx" . "component" "backend") */}}
{{- define "taskboard.selectorLabels" -}}
app.kubernetes.io/name: {{ include "taskboard.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "taskboard.secretName" -}}
{{- if .Values.secret.existingSecret }}{{ .Values.secret.existingSecret }}{{ else }}{{ include "taskboard.fullname" . }}-db{{ end -}}
{{- end }}

{{- define "taskboard.dbHost" -}}
{{- if .Values.postgres.enabled }}{{ include "taskboard.fullname" . }}-postgres{{ else }}{{ required "postgres.externalHost is required when postgres.enabled=false" .Values.postgres.externalHost }}{{ end -}}
{{- end }}

{{- define "taskboard.backendEnv" -}}
envFrom:
  - configMapRef:
      name: {{ include "taskboard.fullname" . }}-config
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "taskboard.secretName" . }}
        key: {{ .Values.secret.passwordKey }}
{{- end }}
