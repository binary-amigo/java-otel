# .NET OpenTelemetry task manager

ASP.NET Core 8 + SQLite sample matching the Java task API. The official OpenTelemetry .NET automatic-instrumentation agent emits OTLP/HTTP traces, metrics, and logs without configuring the OpenTelemetry SDK in application startup. A continuous load generator produces successful, failed, slow, and bad-database requests.

## Run

```bash
cd dotnet-otel
cp .env.example .env
# Edit the three OTLP endpoints and optional headers in .env.
docker compose up --build
```

The API is available at `http://localhost:8051`; the Java app can continue using port 8050. If an OTLP receiver is running on the host at port 4318, the defaults work without edits.

```bash
curl http://localhost:8051/health
curl -X POST http://localhost:8051/tasks/api/ \
  -H 'Content-Type: application/json' \
  -d '{"title":"Try OpenTelemetry","description":"Created manually","completed":false}'
```

The generator runs every five minutes by default and exercises create/list/get/update/delete endpoints, intentional 4xx/5xx responses, invalid SQL, and spans lasting over one second. Tune it with the variables shown in `.env.example`.

Stop and remove the containers with `docker compose down`. Add `-v` only if you also want to erase the persisted SQLite task data.
