FROM maven:3.9.9-eclipse-temurin-11

WORKDIR /app

COPY pom.xml .
RUN mvn -B dependency:go-offline

COPY lib ./lib
COPY src ./src

EXPOSE 8050

CMD ["mvn", "spring-boot:run", "-Dspring-boot.run.jvmArguments=-javaagent:lib/opentelemetry-javaagent.jar"]

