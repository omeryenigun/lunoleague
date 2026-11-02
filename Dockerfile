FROM dart:stable AS api
WORKDIR /api
COPY pubspec.api.yaml pubspec.yaml
COPY lib lib
COPY bin/api_server.dart bin/api_server.dart
RUN dart pub get
# Cap heap so Metal builders don't OOM-kill AOT with no stderr (exit 254).
ENV DART_VM_OPTIONS=--old_gen_heap_size=1536
RUN dart --version \
  && dart compile exe -v bin/api_server.dart -o /api/server

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
COPY assets/images/luno_bilgi_logo.jpg /seed/luno_bilgi_icon.jpg
COPY assets/images/one_button_logo.jpg /seed/one_button_icon.jpg
ENV PORT=8080
ENV ADMIN_WEB_ROOT=/admin_web
EXPOSE 8080
CMD ["/server"]
