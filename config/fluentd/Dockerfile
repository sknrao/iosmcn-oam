# fluentd/Dockerfile
FROM fluent/fluentd:v1.17.0-debian-1.0
USER root
RUN ["gem", "install", "fluent-plugin-elasticsearch", "--no-document", "--version", "5.2.2"]
USER fluent
