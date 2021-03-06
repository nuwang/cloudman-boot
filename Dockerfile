ARG BASE_IMAGE=ubuntu:20.04
ARG WORK_DIR=/opt/cm-boot

#=================================
# STAGE 1
#=================================
FROM $BASE_IMAGE as stage1

ENV PYTHONUNBUFFERED 1
ARG DEBIAN_FRONTEND=noninteractive
ARG WORK_DIR

RUN echo "===> Installing system packages..." \
    && mkdir -p $WORK_DIR \
    && apt-get -qq update && apt-get install -y --no-install-recommends \
        python3-virtualenv \
        # Needed to install netaddr
        gcc \
        curl \
        python3-dev \
        python3-pip \
        python3-setuptools \
    && echo "===> Setup python..."  \
    && virtualenv -p python3 --prompt "(cloudman-boot)" $WORK_DIR/venv \
    # netaddr is for ansible's ipaddr module
    && $WORK_DIR/venv/bin/pip3 install --no-cache-dir ansible requests docker cloudbridge netaddr \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/*


#=================================
# STAGE 2
#=================================
FROM $BASE_IMAGE

ENV KUBE_LATEST_VERSION=v1.19.0
ENV RKE_IN_DOCKER=true
ENV PYTHONUNBUFFERED 1
ARG DEBIAN_FRONTEND=noninteractive
ARG WORK_DIR

RUN echo "===> Installing system packages..." \
    && apt-get -qq update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        python3-virtualenv \
        docker.io \
        # used by helm installer
        gawk \
        # needed by csi-drivers
        nfs-common \
    && echo "==> Installing latest kubectl..." \
    && curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* \
    && mkdir -p $WORK_DIR

COPY --from=stage1 $WORK_DIR $WORK_DIR

WORKDIR /opt/cm-boot
ADD . $WORK_DIR

ENV ANSIBLE_DEBUG=${ANSIBLE_DEBUG:--v}
CMD bash -c "venv/bin/ansible-playbook -e "ansible_python_interpreter=/opt/cm-boot/venv/bin/python" -i 'localhost,' -c local playbook.yml --tags cloudman-boot $ANSIBLE_DEBUG & wait"
