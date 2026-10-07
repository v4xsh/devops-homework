# ---------- Stage 1: build the jar with Maven + JDK 17 ----------
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build

# Resolve plugins/dependencies first so this layer is cached
COPY pom.xml .
RUN mvn -q -B dependency:go-offline

# Compile and package
COPY src ./src
RUN mvn -q -B package -DskipTests

# ---------- Stage 2: run on a small JRE-only image ----------
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Only the built jar is copied - Maven, the JDK and sources stay in stage 1
COPY --from=build /build/target/hello-java.jar app.jar

EXPOSE 8080

CMD ["java", "-jar", "app.jar"]
