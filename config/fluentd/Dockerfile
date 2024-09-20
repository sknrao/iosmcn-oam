# fluentd/Dockerfile
FROM fluent/fluentd:v1.17.0-debian-1.0
USER root
RUN gem uninstall elasticsearch && gem install elasticsearch -v 7.17
RUN ["gem", "install", "fluent-plugin-elasticsearch", "--no-document", "--version", "5.4.0"]
USER fluent
