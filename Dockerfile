FROM mcr.microsoft.com/mssql/server:2022-latest

# Wings runs containers as its system user (default uid 988). Match it so
# sqlservr has a passwd entry. Override with --build-arg if yours differs.
ARG CONTAINER_UID=988

USER root

# sqlservr ships with the file capability cap_net_bind_service. Wings drops
# that capability from every container, and the kernel refuses to exec a
# binary whose file caps exceed the bounding set: "Operation not permitted".
# Rewriting each file drops the security.capability xattr; ports above 1024
# need no privilege anyway.
RUN find /opt/mssql /opt/mssql-tools* -type f -perm -u+x 2>/dev/null | while read -r f; do \
      cp "$f" "$f.nocap" && chmod --reference="$f" "$f.nocap" && mv -f "$f.nocap" "$f"; \
    done

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
