FROM dart:stable AS api
WORKDIR /api
COPY pubspec.api.yaml pubspec.yaml
COPY lib lib
COPY bin/api_server.dart bin/api_server.dart
RUN dart pub get
RUN dart compile exe bin/api_server.dart -o /api/server

FROM debian:bookworm-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY --from=api /api/server /server
COPY admin_web /admin_web
ENV PORT=8080
ENV ADMIN_WEB_ROOT=/admin_web
EXPOSE 8080
CMD ["/server"]
