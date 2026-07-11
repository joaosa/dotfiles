# Claude Code and Codex devcontainer, adapted from Trail of Bits' pinned
# claude-code-devcontainer template and OpenAI's secure devcontainer example.
FROM ghcr.io/astral-sh/uv:0.10@sha256:10902f58a1606787602f303954cea099626a4adb02acbac4c69920fe9d278f82 AS uv
FROM mcr.microsoft.com/devcontainers/base:ubuntu24.04@sha256:4bcb1b466771b1ba1ea110e2a27daea2f6093f9527fb75ee59703ec89b5561cb

ARG TZ
ENV TZ="$TZ"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
  bubblewrap \
  socat \
  fd-find \
  ripgrep \
  tmux \
  zsh \
  build-essential \
  jq \
  nano \
  unzip \
  vim \
  dnsutils \
  ipset \
  iptables \
  iproute2 \
  && chmod u+s /usr/bin/bwrap \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# The base image grants vscode passwordless NOPASSWD:ALL. In the audit profile
# the untrusted agent runs as vscode, so unrestricted sudo would let it undo the
# firewall, mounts, and dropped capabilities (e.g. `sudo iptables -F`). Replace
# it with a narrow allowlist of exactly the commands the setup scripts run.
# Sudoers matches wildcards with fnmatch (no `/` special-casing), so the path
# arguments below still constrain each command to its intended targets.
COPY sudoers-agent /etc/sudoers.d/agent-devcontainer
RUN find /etc/sudoers.d -type f ! -name agent-devcontainer \
      -exec grep -qE '^[^#]*\bvscode\b' {} \; -delete && \
  chmod 0440 /etc/sudoers.d/agent-devcontainer && \
  chown root:root /etc/sudoers.d/agent-devcontainer && \
  visudo -cf /etc/sudoers.d/agent-devcontainer

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  curl -fsSL "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" -o /tmp/git-delta.deb && \
  dpkg -i /tmp/git-delta.deb && \
  rm /tmp/git-delta.deb

COPY --from=uv /uv /usr/local/bin/uv

ARG FZF_VERSION=0.70.0
RUN ARCH=$(dpkg --print-architecture) && \
  case "${ARCH}" in \
    amd64) FZF_ARCH="linux_amd64" ;; \
    arm64) FZF_ARCH="linux_arm64" ;; \
    *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
  esac && \
  curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-${FZF_ARCH}.tar.gz" | tar -xz -C /usr/local/bin

RUN mkdir -p /commandhistory /workspace /home/vscode/.claude /home/vscode/.codex /opt && \
  touch /commandhistory/.bash_history /commandhistory/.zsh_history && \
  chown -R vscode:vscode /commandhistory /workspace /home/vscode/.claude /home/vscode/.codex /opt

ENV DEVCONTAINER=true
ENV SHELL=/bin/zsh
ENV EDITOR=nano
ENV VISUAL=nano

WORKDIR /workspace
USER vscode

ENV PATH="/home/vscode/.local/bin:$PATH"

RUN curl -fsSL https://claude.ai/install.sh | bash && \
  claude plugin marketplace add anthropics/skills && \
  claude plugin marketplace add trailofbits/skills && \
  claude plugin marketplace add trailofbits/skills-curated

RUN uv python install 3.13 --default
RUN uv tool install ast-grep-cli

ARG NODE_VERSION=22
ARG CODEX_VERSION=0.144.1
ENV FNM_DIR="/home/vscode/.fnm"
RUN curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell && \
  export PATH="$FNM_DIR:$PATH" && \
  eval "$(fnm env)" && \
  fnm install "${NODE_VERSION}" && \
  fnm default "${NODE_VERSION}" && \
  npm install --global "@openai/codex@${CODEX_VERSION}"

ENV PATH="/home/vscode/.fnm/aliases/default/bin:/home/vscode/.local/bin:$PATH"

ARG ZSH_IN_DOCKER_VERSION=1.2.1
RUN sh -c "$(curl -fsSL https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
  -p git \
  -x

COPY --chown=vscode:vscode .zshrc /home/vscode/.zshrc.custom
RUN echo 'source ~/.zshrc.custom' >> /home/vscode/.zshrc

COPY --chown=vscode:vscode post_install.py /opt/post_install.py
COPY --chown=vscode:vscode --chmod=0755 post-start.sh /opt/post_start.sh
COPY --chmod=0500 init-firewall.sh /usr/local/bin/init-firewall.sh
COPY --chmod=0500 apply-firewall.sh /usr/local/bin/apply-firewall.sh
