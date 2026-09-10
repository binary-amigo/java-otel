
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
- `load-generator`: every 5 minutes, sends 50 requests to each task REST API, intentionally makes 10 of those requests fail for each API, and sends 5 slow database-backed requests where the API takes more than 1 second and the database query takes more than 500 ms.

Tune the generator with compose environment variables:

- `REQUESTS_PER_API`: total requests per API per cycle. Defaults to `50`.
- `FAILED_REQUESTS_PER_API`: intentional failed requests per API per cycle. Defaults to `10`.
- `CYCLE_SECONDS`: cycle duration. Defaults to `300` seconds.
- `SLOW_REQUESTS_PER_CYCLE`: slow DB requests per cycle. Defaults to `5`.
- `SLOW_REQUEST_DELAY_MS`: delay applied to each slow DB request. Defaults to `1200` ms.
- `SLOW_DB_DELAY_MS`: delay executed inside the database query for slow DB requests. Defaults to `600` ms.
- `REQUEST_TIMEOUT`: curl timeout per generated request. Defaults to `15` seconds.
