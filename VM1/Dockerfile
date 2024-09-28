FROM openjdk:17-jdk-alpine

COPY app.jar /app/app.jar

WORKDIR /app

HEALTHCHECK --interval=10s --timeout=30s CMD curl -f http://localhost:8080/index.html || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
