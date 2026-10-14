# uv separat beziehen: Die Version lässt sich an genau einer Stelle ändern.
ARG UV_VERSION=0.12.24
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

FROM debian:bookworm-slim

ARG USERNAME=devpod
ARG USER_UID=1000
ARG USER_GID=1000

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    UV_LINK_MODE=copy

# Weitere Systemprogramme hier alphabetisch ergänzen und danach neu bauen.
# ca-certificates: HTTPS; openssh-client: Git über SSH / SSH-Agent.
# libstdc++6: Laufzeitbibliothek für den optionalen VS-Code-Server.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        libstdc++6 \
        mc \
        openssh-client \
        sudo \
        tmux \
        unzip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=uv /uv /uvx /usr/local/bin/

# Im Alltag als normaler Benutzer arbeiten; sudo nur bei Bedarf verwenden.
RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" \
        --create-home --shell /bin/bash "${USERNAME}" \
    && printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${USERNAME}" \
        > "/etc/sudoers.d/${USERNAME}" \
    && chmod 0440 "/etc/sudoers.d/${USERNAME}" \
    && visudo -cf "/etc/sudoers.d/${USERNAME}" \
    \
    # Create user directories
    && mkdir -p \
        "/home/${USERNAME}/.local/bin" \
        "/home/${USERNAME}/.local/share/uv" \
        "/home/${USERNAME}/.cache/uv" \
        /workspaces \
    \
    # Fix ownership and permissions
    && chown -R "${USER_UID}:${USER_GID}" \
        "/home/${USERNAME}/.local" \
        "/home/${USERNAME}/.cache" \
    && chown "${USER_UID}:${USER_GID}" /workspaces

ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"

USER ${USERNAME}
WORKDIR /workspaces
CMD ["sleep", "infinity"]
