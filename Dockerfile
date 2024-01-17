FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe example/bootstrap_server.dart -o p2p_bootstrap

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/p2p_bootstrap /app/p2p_bootstrap

CMD [ "/app/p2p_bootstrap" ]