FROM benok/os-debianconsole-base
# FROM amd64=debian:buster arm64=arm64v8/buster:stable

COPY build/sshd_config.append.tpl /etc/ssh/
COPY build/generate-lsb-release /etc/init.d/

RUN apt-get update \
    && apt-get install -y --no-install-recommends iptables openssh-server rsync locales \
                           sudo vim less curl ca-certificates psmisc htop kmod iproute2 \
                           net-tools bash-completion wget \
                           nano open-iscsi iputils-ping \
    && update-alternatives --set iptables /usr/sbin/iptables-legacy \
    && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /etc/ssh/*key* \
    && locale-gen en_US.UTF-8 \
    && addgroup --gid 1100 rancher \
    && addgroup --gid 1101 docker \
    && useradd -u 1100 -g rancher -G docker,sudo -m -s /bin/bash rancher \
    && useradd -u 1101 -g docker -G docker,sudo -m -s /bin/bash docker \
    && echo '## allow password less for rancher user' >> /etc/sudoers \
    && echo 'rancher ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers \
    && echo '## allow password less for docker user' >> /etc/sudoers \
    && echo 'docker ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers \
    && ln -s /bin/ps /usr/bin/ps \
    && cat /etc/ssh/sshd_config > /etc/ssh/sshd_config.tpl \
    && cat /etc/ssh/sshd_config.append.tpl >> /etc/ssh/sshd_config.tpl \
    && rm -f /etc/ssh/sshd_config.append.tpl /etc/ssh/sshd_config \
    && echo > /etc/motd \
    \
    && addgroup --gid 1200 user-docker \
    && adduser --system -u 1200 --gid 1200 --disabled-login --no-create-home user-docker \
    && echo 'user-docker:100000:65536' > /etc/subuid \
    && echo 'user-docker:100000:65536' > /etc/subgid

COPY build/iscsid.conf /etc/iscsi/

ENTRYPOINT ["/usr/bin/ros", "entrypoint"]
