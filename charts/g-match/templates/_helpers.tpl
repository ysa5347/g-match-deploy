{{/*
Common labels
*/}}
{{- define "g-match.labels" -}}
app.kubernetes.io/name: g-match
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{/*
MySQL FQDN (auto-computed from service name and namespace)
*/}}
{{- define "g-match.mysql.host" -}}
{{- printf "%s.%s.svc.cluster.local" .Values.mysql.serviceName .Release.Namespace -}}
{{- end -}}

{{/*
Redis FQDN (auto-computed from service name and namespace)
*/}}
{{- define "g-match.redis.host" -}}
{{- printf "%s.%s.svc.cluster.local" .Values.redis.serviceName .Release.Namespace -}}
{{- end -}}

{{/*
Django image full reference
*/}}
{{- define "g-match.django.image" -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.django.repository .Values.image.django.tag -}}
{{- end -}}

{{/*
Matcher image full reference
*/}}
{{- define "g-match.matcher.image" -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.matcher.repository .Values.image.matcher.tag -}}
{{- end -}}

{{/*
Node affinity to exclude control-plane nodes
*/}}
{{- define "g-match.nodeAffinity" -}}
{{- if .Values.global.excludeControlPlane }}
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.kubernetes.io/control-plane
          operator: DoesNotExist
{{- end }}
{{- end -}}

{{/*
Image pull secrets
*/}}
{{- define "g-match.imagePullSecrets" -}}
{{- if .Values.image.pullSecrets }}
imagePullSecrets:
{{- range .Values.image.pullSecrets }}
- name: {{ .name }}
{{- end }}
{{- end }}
{{- end -}}
