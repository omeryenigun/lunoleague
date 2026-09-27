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
COPY assets/images/logo.png /seed/luno_league_icon.png
COPY store/feature-graphic.png /seed/luno_league_gallery.png
COPY assets/site/luno_play.png /seed/luno_shot_play.png
COPY assets/site/luno_win.png /seed/luno_shot_win.png
ENV PORT=8080
ENV ADMIN_WEB_ROOT=/admin_web
EXPOSE 8080
CMD ["/server"]
