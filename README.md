
OTEL_SERVICE_NAME=task-manager-java-local \
OTEL_RESOURCE_ATTRIBUTES="deployment.environment=staging,service.version=1.0.0" \
OTEL_TRACES_EXPORTER=otlp \
OTEL_LOGS_EXPORTER=otlp \
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="http://demo.codexray.io/ingest/v1/traces" \
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT="http://demo.codexray.io/ingest/v1/logs" \
OTEL_EXPORTER_OTLP_HEADERS="x-api-key=nz1675de, X-Metrics-Type=otel" \
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
OTEL_METRICS_EXPORTER=otlp \
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT="http://demo.codexray.io/ingest/v1/metrics" \
mvn spring-boot:run -Dspring-boot.run.jvmArguments="-javaagent:lib/opentelemetry-javaagent.jar"

## Docker Compose with continuous load

Run the app with the OpenTelemetry Java agent and the configured OTLP exporters:

```bash
docker compose up --build
```

The compose file starts:

- `app`: runs `mvn spring-boot:run -Dspring-boot.run.jvmArguments="-javaagent:lib/opentelemetry-javaagent.jar"` on port `8050` with `OTEL_SERVICE_NAME=db-test`.
- `load-generator`: continuously calls the task API and periodically triggers `/tasks/api/test/bad-query` to produce database error telemetry.

Tune the generator with compose environment variables:

- `SLEEP_SECONDS`: delay between iterations. Defaults to `2`.
- `BAD_QUERY_EVERY`: trigger the bad-query endpoint every N iterations. Defaults to `10`.
