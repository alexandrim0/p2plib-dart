from dart:2.18
RUN apt-get update && \
    apt-get install -y \
    libsodium-dev && \ 
    apt-get clean
COPY ./ /tmp/p2plib
RUN cd /tmp/p2plib && \
    dart pub get && \
    dart compile exe example/bootstrap_server.dart && \
    mv /tmp/p2plib/example/bootstrap_server.exe /usr/local/bin/bootstrap_server && \
    rm -r /tmp/p2plib 
