FROM dart:stable AS build

WORKDIR /tmp/

RUN apt-get update && apt-get install -y libsodium-dev

COPY ./ ./

RUN dart pub get && dart compile exe -o p2p_bootstrap example/bootstrap_server.dart

FROM scratch

COPY --from=build /runtime/ /

COPY --from=build /usr/lib/ /usr/lib/

COPY --from=build /tmp/p2p_bootstrap /p2p_bootstrap

EXPOSE 2022/udp

CMD [ "/p2p_bootstrap" ]
