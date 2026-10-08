FROM mcr.microsoft.com/mssql/server:2022-latest

# Wings runs containers as its system user (default uid 988). Match it so
# sqlservr has a passwd entry. Override with --build-arg if yours differs.
ARG CONTAINER_UID=988

USER root
RUN useradd -m -u ${CONTAINER_UID} -d /home/container -s /bin/bash container \
 && rm -rf /var/opt/mssql \
 && ln -s /home/container/mssql /var/opt/mssql

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENV USER=container HOME=/home/container
USER container
WORKDIR /home/container

STOPSIGNAL SIGINT
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
