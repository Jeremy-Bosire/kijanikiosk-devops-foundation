FROM jenkins/jenkins:2.580.1-lts-jdk21

USER root
# Docker CLI only (no daemon): Jenkins talks to the host daemon via the mounted socket
# to start the pinned Node.js agent container for each build.
ARG DOCKER_CLI_VERSION=27.3.1
RUN curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_CLI_VERSION}.tgz" \
      | tar -xz -C /usr/local/bin --strip-components=1 docker/docker \
 && docker --version

USER jenkins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
