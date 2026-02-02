#!/bin/bash

# Run the Spring Boot application with OpenTelemetry Java Agent
./mvnw spring-boot:run -Dspring-boot.run.jvmArguments="-javaagent:lib/opentelemetry-javaagent.jar" 