# Set local username
ARG username
ARG DEPLOY_USER=${username}

# Defend against Sury GPG key issues
RUN curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
RUN dpkg -i /tmp/debsuryorg-archive-keyring.deb
RUN sh -c 'echo "deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'

# Prepare for Ansible.
RUN apt-get update && \
    apt-get install -y -o Dpkg::Options::="--force-confnew" python3-dev python3-venv python3-pymysql udhcpc isc-dhcp-client udhcpc isc-dhcp-client

# Creating dir if it is neccessary.
RUN if [ ! -d "/home/$DEPLOY_USER" ]; then \
        mkdir -p /home/$DEPLOY_USER && \
        chown $DEPLOY_USER:$DEPLOY_USER /home/$DEPLOY_USER; \
    fi

# Install Ansible.
USER $DEPLOY_USER
WORKDIR /home/$DEPLOY_USER

RUN python3 -m venv ansible && \
    ./ansible/bin/pip3 install ansible netaddr boto3 && \
    ./ansible/bin/ansible-galaxy collection install ansible.posix --force

# Fetch ce-provision code.
RUN git clone --branch 2.x https://gitlab.com/code-enigma/ce-provision.git ./ce-provision
COPY --chown=$DEPLOY_USER:$DEPLOY_USER ./provision.yml ./ce-provision/provision.yml
RUN cp /home/${DEPLOY_USER}/ce-provision/roles/debian/ce_deploy/meta/requirements-12.yml /home/${DEPLOY_USER}/ce-provision/roles/debian/ce_deploy/meta/requirements-13.yml

# Install CE tools. passing ddev username to ansible.
RUN ./ansible/bin/ansible-playbook ./ce-provision/provision.yml --extra-vars "ddev_user=${DEPLOY_USER}"
RUN rm ./ce-provision/provision.yml

# Switch back to root for ddev tasks
USER root