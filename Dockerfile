# ARM64 krunkit stack retained from source commit a76de47f75362ef6f34fe21771383c70f90c5379.
FROM registry.fedoraproject.org/fedora@sha256:dbb22055c0c19f4eba2afbbb717667b0c76aa956c4283700041980ad3710bb73
COPY mesa-krunkit.repo /etc/yum.repos.d/mesa-krunkit.repo
RUN dnf install -y --disablerepo=fedora-cisco-openh264 --setopt=install_weak_deps=False \
      ollama-0.24.0-4.fc45 ollama-vulkan-0.24.0-4.fc45 \
      mesa-vulkan-drivers-25.3.6-102.fc44 mesa-filesystem-25.3.6-102.fc44 \
      vulkan-tools python3 python3-pip tar \
    && dnf clean all \
    && rpm -qa | sort > /etc/ollama-image-packages.txt \
    && test -f /usr/share/vulkan/icd.d/virtio_icd.aarch64.json
COPY requirements.lock /opt/llm/requirements.lock
RUN python3 -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir -r /opt/llm/requirements.lock
COPY contracts /opt/contracts
COPY pyproject.toml /opt/llm/pyproject.toml
COPY src /opt/llm/src
RUN /opt/venv/bin/pip wheel --no-deps --wheel-dir /opt/wheels /opt/contracts /opt/llm \
    && /opt/venv/bin/pip install --no-deps /opt/wheels/*.whl \
    && mkdir /models && chown 10001:10001 /models
ENV PATH=/opt/venv/bin:$PATH PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 \
    HOME=/tmp/ollama-home XDG_CACHE_HOME=/tmp/cache XDG_RUNTIME_DIR=/tmp/runtime \
    OLLAMA_HOST=127.0.0.1:11434 OLLAMA_MODELS=/models OLLAMA_VULKAN=1 \
    OLLAMA_NUM_PARALLEL=1 OLLAMA_MAX_LOADED_MODELS=1 OLLAMA_KEEP_ALIVE=5m \
    VK_DRIVER_FILES=/usr/share/vulkan/icd.d/virtio_icd.aarch64.json \
    THRIFT_BIND_HOST=0.0.0.0 HEALTH_BIND_HOST=0.0.0.0
USER 10001:10001
EXPOSE 9091 11435
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=10s --timeout=3s --start-period=1200s CMD ["python3", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:11435/ready', timeout=2)"]
ENTRYPOINT ["llm-service"]
