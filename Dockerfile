FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe example/bootstrap_server.dart -o p2p_bootstrap

FROM debian:stable-slim
RUN apt-get update \
    && apt-get install -y libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/p2p_bootstrap /app/p2p_bootstrap

CMD [ "/app/p2p_bootstrap" ]