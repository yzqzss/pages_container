FROM alpine:latest

RUN set -eux; \
    apk update; \
    apk add --no-cache openssh bash zstd rsync htop wget curl; \
    rm -rf /var/cache/apk/*;

# use 22555 as ssh port
RUN set -eux; \
    sed -i 's/#Port 22/Port 22555/g' /etc/ssh/sshd_config;

# add `pages` user group
RUN set -eux; \
    addgroup pages -g 22555;

# add low-privileged user form `users.list`, and create user's home directory
COPY build/users.list /users.list
RUN set -eux; \
    # read users from `/users.list`
    while IFS= read -r line; do \
        echo "add user: $line"; \
        mkdir -p /home/$line; \
        adduser -D -s /bin/sh -h /home/$line $line; \
        addgroup $line pages; \
        echo "$line:$(openssl rand -base64 32)" | chpasswd; \
    done < /users.list;



# disable password login
RUN set -eux; \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config;


# add user's public key to authorized_keys from `build/users_pubkeys/{suer}`
COPY build/users_pubkeys /tmp/users_pubkeys
RUN set -eux; \
    while IFS= read -r line; do \
        mkdir -p /home/$line/.ssh; \
        cat /tmp/users_pubkeys/$line.pub > /home/$line/.ssh/authorized_keys; \
        chown -R $line:$line /home/$line/.ssh; \
        chmod 700 /home/$line/.ssh; \
        chmod 600 /home/$line/.ssh/authorized_keys; \
    done < /users.list;

# create /www directory
RUN set -eux; \
    mkdir -p /www

# keep sshd host keys
VOLUME /etc/ssh

EXPOSE 22555

# start sshd
CMD set -eux; \
    # copy /host-keys/* to /etc/ssh/
    cp /host-keys/* /etc/ssh/ -f || true; \
    ssh-keygen -A; \
    # set permission for host keys
    chmod 600 /etc/ssh/ssh_host_*_key.pub; \
    chmod 400 /etc/ssh/ssh_host_*_key; \
    # copy back keys to /host-keys/
    cp /etc/ssh/ssh_host_*_key /host-keys/; \
    cp /etc/ssh/ssh_host_*_key.pub /host-keys/; \
    # lock down /host-keys/
    chmod 600 /host-keys -R; \
    chown root:root /host-keys -R; \
    # set permission for /www
    chown root:root /www; \
    chmod 775 /www; \
    # create /www/{user} directory for each user
    # users can't w|r|x other users' files
    while IFS= read -r line; do \
        mkdir -p /www/$line; \
        chown $line:pages /www/$line; \
        chmod 705 /www/$line; \
        # link /www/{user} to /home/{user}/www
        ln -sr -f /www/$line/ /home/$line/www; \
    done < /users.list; \
    # start sshd
    exec /usr/sbin/sshd -D -e