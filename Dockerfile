# Basic Gleam Dockerfile
FROM ghcr.io/gleam-lang/gleam:v1.14.0-erlang-alpine

WORKDIR /app

# Copy manifest files for dependency caching
COPY gleam.toml manifest.toml ./

# Download dependencies
RUN gleam deps download

# Copy source code and build
COPY src/ src/
COPY test/ test/
RUN gleam build

EXPOSE 8080

CMD ["gleam", "run"]