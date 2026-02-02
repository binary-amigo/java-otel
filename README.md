
OTEL_SERVICE_NAME=task-manager-java-local \
OTEL_RESOURCE_ATTRIBUTES="deployment.environment=staging,service.version=1.0.0" \
OTEL_TRACES_EXPORTER=otlp \
OTEL_LOGS_EXPORTER=otlp \
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="http://demo.codexray.io/v1/traces" \
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT="http://demo.codexray.io/v1/logs" \
OTEL_EXPORTER_OTLP_HEADERS="x-api-key=nz1675de, X-Metrics-Type=otel" \
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
OTEL_METRICS_EXPORTER=otlp \
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT="http://demo.codexray.io/v1/metrics" \
mvn spring-boot:run -Dspring-boot.run.jvmArguments="-javaagent:lib/opentelemetry-javaagent.jar"