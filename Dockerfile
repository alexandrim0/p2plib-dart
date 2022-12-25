FROM dart:2.18 AS builder

WORKDIR /tmp/

RUN apt-get update && apt-get install -y libsodium-dev

COPY ./ ./

RUN dart pub get && dart compile exe -o p2p_bootstrap example/bootstrap_server.dart

FROM alpine:latest

COPY --from=builder /tmp/p2p_bootstrap /root/p2p_bootstrap

CMD [ "/root/p2p_bootstrap" ]
