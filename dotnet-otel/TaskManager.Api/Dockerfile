FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY TaskManager.Api.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
ARG OTEL_DOTNET_AUTO_VERSION=1.16.0
ENV OTEL_DOTNET_AUTO_HOME=/otel-dotnet-auto

ADD https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation/releases/download/v${OTEL_DOTNET_AUTO_VERSION}/otel-dotnet-auto-install.sh /tmp/otel-dotnet-auto-install.sh
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip \
    && sh /tmp/otel-dotnet-auto-install.sh \
    && chmod +x /otel-dotnet-auto/instrument.sh

WORKDIR /app
COPY --from=build /app/publish .
RUN mkdir -p /app/data
EXPOSE 8050
ENV ASPNETCORE_HTTP_PORTS=8050
ENTRYPOINT ["/otel-dotnet-auto/instrument.sh", "dotnet", "TaskManager.Api.dll"]
