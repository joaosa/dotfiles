# Claude Code and Codex devcontainer, adapted from Trail of Bits' pinned
# claude-code-devcontainer template and OpenAI's secure devcontainer example.
FROM ghcr.io/astral-sh/uv:0.10@sha256:10902f58a1606787602f303954cea099626a4adb02acbac4c69920fe9d278f82 AS uv
FROM mcr.microsoft.com/devcontainers/base:ubuntu24.04@sha256:4bcb1b466771b1ba1ea110e2a27daea2f6093f9527fb75ee59703ec89b5561cb

ARG TZ
ENV TZ="$TZ"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# No bubblewrap: every profile runs Codex with the container as its external
# sandbox (AGENT_CODEX_EXTERNAL_SANDBOX=1), so Codex never spawns its nested
# bwrap. A setuid-root bwrap would be latent local-root surface for no benefit,
# and this profile blocks the user namespaces unprivileged bwrap needs anyway.
# Only packages the base image lacks (EDITOR=nano ships in the base).
RUN apt-get update && apt-get install -y --no-install-recommends \
  fd-find \
  ripgrep \
  zsh \
  jq \
  dnsutils \
  ipset \
  iptables \
  iproute2 \
  libleptonica-dev \
  libtesseract-dev \
  pkg-config \
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

# Pin release assets by SHA-256, not just version tag: a retagged or
# compromised release would otherwise execute at build time as root. Update
# both digests whenever GIT_DELTA_VERSION changes.
ARG GIT_DELTA_VERSION=0.18.2
ARG GIT_DELTA_SHA256_amd64=1658c7b61825d411b50734f34016101309e4b6e7f5799944cf8e4ac542cebd7f
ARG GIT_DELTA_SHA256_arm64=937781aa7788e1510858743fff6c9a8b4a69fe0a22a7c8a69493e633227939a9
RUN ARCH=$(dpkg --print-architecture) && \
  eval "EXPECT=\${GIT_DELTA_SHA256_${ARCH}}" && \
  [ -n "$EXPECT" ] || { echo "No git-delta digest for arch ${ARCH}" >&2; exit 1; } && \
  curl -fsSL "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" -o /tmp/git-delta.deb && \
  echo "${EXPECT}  /tmp/git-delta.deb" | sha256sum -c - && \
  dpkg -i /tmp/git-delta.deb && \
  rm /tmp/git-delta.deb

COPY --from=uv /uv /uvx /usr/local/bin/

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
ARG PRE_COMMIT_VERSION=4.6.1
RUN uv tool install "pre-commit==${PRE_COMMIT_VERSION}"

# Rust toolchain + task-runner tooling so agent sessions in the Rust repos
# (second-brain-tools et al.) get working gates, fmt, and tests instead of
# degraded fallbacks. rustup-init is version-pinned and digest-checked
# against the official .sha256 published at the same archive path.
ARG RUSTUP_VERSION=1.29.0
ARG RUSTUP_SHA256_amd64=4acc9acc76d5079515b46346a485974457b5a79893cfb01112423c89aeb5aa10
ARG RUSTUP_SHA256_arm64=9732d6c5e2a098d3521fca8145d826ae0aaa067ef2385ead08e6feac88fa5792
ARG RUST_TOOLCHAIN=1.97.1
RUN ARCH=$(dpkg --print-architecture) && \
  case "$ARCH" in amd64) T=x86_64 ;; arm64) T=aarch64 ;; *) echo "unsupported arch ${ARCH}" >&2; exit 1 ;; esac && \
  eval "EXPECT=\${RUSTUP_SHA256_${ARCH}}" && \
  curl -fsSL "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${T}-unknown-linux-gnu/rustup-init" -o /tmp/rustup-init && \
  echo "${EXPECT}  /tmp/rustup-init" | sha256sum -c - && \
  chmod +x /tmp/rustup-init && \
  /tmp/rustup-init -y --profile minimal --default-toolchain "${RUST_TOOLCHAIN}" -c rustfmt -c clippy -c rust-analyzer -c llvm-tools && \
  rm /tmp/rustup-init
ENV PATH="/home/vscode/.cargo/bin:$PATH"

# Standalone release binaries, each digest-pinned per arch: just (task
# runner), cargo-nextest (test runner), shellcheck (pre-commit parity),
# sccache (the workspace .cargo/config.toml sets rustc-wrapper = "sccache",
# so cargo is dead without it).
ARG JUST_VERSION=1.42.4
ARG JUST_SHA256_amd64=678efc1cfbd5fa5a88375daa7e2f3864a049d6d63a0296df925a2ae5f516cb56
ARG JUST_SHA256_arm64=beb35a4ed1208ffbb0fef26042c65875759a5358b9ee1a7856dec8490dfd4aca
ARG NEXTEST_VERSION=0.9.143
ARG NEXTEST_SHA256_amd64=66786b9abe23920d022a182d1416b1bbc8130dd4872a9553d76985a1708dcd1e
ARG NEXTEST_SHA256_arm64=2a64b3566a92508550a7ab29c3e8db25472ca37730ecb4d22100b6aa440c2a68
ARG SHELLCHECK_VERSION=0.11.0
ARG SHELLCHECK_SHA256_amd64=8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198
ARG SHELLCHECK_SHA256_arm64=12b331c1d2db6b9eb13cfca64306b1b157a86eb69db83023e261eaa7e7c14588
ARG SCCACHE_VERSION=0.10.0
ARG SCCACHE_SHA256_amd64=1fbb35e135660d04a2d5e42b59c7874d39b3deb17de56330b25b713ec59f849b
ARG SCCACHE_SHA256_arm64=d6a1ce4acd02b937cd61bc675a8be029a60f7bc167594c33d75732bbc0a07400
RUN ARCH=$(dpkg --print-architecture) && \
  case "$ARCH" in amd64) T=x86_64 ;; arm64) T=aarch64 ;; *) echo "unsupported arch ${ARCH}" >&2; exit 1 ;; esac && \
  mkdir -p /home/vscode/.local/bin && cd /tmp && \
  eval "EXPECT=\${JUST_SHA256_${ARCH}}" && \
  curl -fsSL "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-${T}-unknown-linux-musl.tar.gz" -o just.tgz && \
  echo "${EXPECT}  just.tgz" | sha256sum -c - && \
  tar xzf just.tgz just && install -m 0755 just /home/vscode/.local/bin/just && \
  eval "EXPECT=\${NEXTEST_SHA256_${ARCH}}" && \
  curl -fsSL "https://github.com/nextest-rs/nextest/releases/download/cargo-nextest-${NEXTEST_VERSION}/cargo-nextest-${NEXTEST_VERSION}-${T}-unknown-linux-gnu.tar.gz" -o nextest.tgz && \
  echo "${EXPECT}  nextest.tgz" | sha256sum -c - && \
  tar xzf nextest.tgz cargo-nextest && install -m 0755 cargo-nextest /home/vscode/.cargo/bin/cargo-nextest && \
  eval "EXPECT=\${SHELLCHECK_SHA256_${ARCH}}" && \
  curl -fsSL "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.${T}.tar.xz" -o shellcheck.txz && \
  echo "${EXPECT}  shellcheck.txz" | sha256sum -c - && \
  tar xJf shellcheck.txz "shellcheck-v${SHELLCHECK_VERSION}/shellcheck" && \
  install -m 0755 "shellcheck-v${SHELLCHECK_VERSION}/shellcheck" /home/vscode/.local/bin/shellcheck && \
  eval "EXPECT=\${SCCACHE_SHA256_${ARCH}}" && \
  curl -fsSL "https://github.com/mozilla/sccache/releases/download/v${SCCACHE_VERSION}/sccache-v${SCCACHE_VERSION}-${T}-unknown-linux-musl.tar.gz" -o sccache.tgz && \
  echo "${EXPECT}  sccache.tgz" | sha256sum -c - && \
  tar xzf sccache.tgz "sccache-v${SCCACHE_VERSION}-${T}-unknown-linux-musl/sccache" && \
  install -m 0755 "sccache-v${SCCACHE_VERSION}-${T}-unknown-linux-musl/sccache" /home/vscode/.local/bin/sccache && \
  rm -rf /tmp/just.tgz /tmp/just /tmp/nextest.tgz /tmp/cargo-nextest \
    /tmp/shellcheck.txz "/tmp/shellcheck-v${SHELLCHECK_VERSION}" \
    /tmp/sccache.tgz "/tmp/sccache-v${SCCACHE_VERSION}-${T}-unknown-linux-musl"

# Commit-path and audit-parity tooling, same digest-per-arch pattern: gitleaks
# (pre-commit secrets gate) and the cargo audit suite (just sec / just drift).
# musl builds where the publisher ships them; cargo-audit and cargo-machete
# publish no arm64 musl, so arm64 takes their gnu builds instead.
ARG GITLEAKS_VERSION=8.30.1
ARG GITLEAKS_SHA256_amd64=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
ARG GITLEAKS_SHA256_arm64=e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080
ARG CARGO_DENY_VERSION=0.20.2
ARG CARGO_DENY_SHA256_amd64=9f12ed4c49936e09b48bf862b595cde2fe64fcbd9d74dfacac6131ca824c8d5f
ARG CARGO_DENY_SHA256_arm64=995c82be0defc7a025cae49a2aa2644ce8245c9a3318fc4103907c6a285e8c7d
ARG CARGO_AUDIT_VERSION=0.22.2
ARG CARGO_AUDIT_SHA256_amd64=7fb9497f8594b389e5fce5ef9b92db08432996895b2e0c5a0167a69ed445c428
ARG CARGO_AUDIT_SHA256_arm64=c6603814ddaa45e51263dafd31c0ac98808f688d26f7395804f9670b0fd599dd
ARG CARGO_LLVM_COV_VERSION=0.8.7
ARG CARGO_LLVM_COV_SHA256_amd64=967b5cc996c29d8baa52bbb4595ef1f53af35255af8e2036ddbc6468d7b523c7
ARG CARGO_LLVM_COV_SHA256_arm64=b7bb2ad514166f3b19fc06874c577eefde0010e5ac571f9ae33ff45cd19a4785
ARG CARGO_MACHETE_VERSION=0.9.2
ARG CARGO_MACHETE_SHA256_amd64=48200087f54c55aabcd4db4af1e25742b49846c02a1b1bfa134711945b35b2e9
ARG CARGO_MACHETE_SHA256_arm64=6f96c3e6026a5bdd241b6ae600c6fb86c9197c6e189a894f91371baa01fd10f5
RUN ARCH=$(dpkg --print-architecture) && \
  case "$ARCH" in \
    amd64) GL_ARCH=x64; MUSL=x86_64-unknown-linux-musl; ALT=$MUSL ;; \
    arm64) GL_ARCH=arm64; MUSL=aarch64-unknown-linux-musl; ALT=aarch64-unknown-linux-gnu ;; \
    *) echo "unsupported arch ${ARCH}" >&2; exit 1 ;; \
  esac && \
  fetch() { \
    eval "EXPECT=\${${2}_${ARCH}}" && \
    [ -n "$EXPECT" ] || { echo "No $1 digest for arch ${ARCH}" >&2; exit 1; } && \
    curl -fsSL "$3" -o /tmp/tool.tgz && \
    echo "${EXPECT}  /tmp/tool.tgz" | sha256sum -c - && \
    mkdir -p /tmp/tool && tar -xzf /tmp/tool.tgz -C /tmp/tool && \
    install -m 0755 "$(find /tmp/tool -type f -name "$1")" "$4/$1" && \
    rm -rf /tmp/tool.tgz /tmp/tool; \
  } && \
  fetch gitleaks GITLEAKS_SHA256 "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${GL_ARCH}.tar.gz" /home/vscode/.local/bin && \
  fetch cargo-deny CARGO_DENY_SHA256 "https://github.com/EmbarkStudios/cargo-deny/releases/download/${CARGO_DENY_VERSION}/cargo-deny-${CARGO_DENY_VERSION}-${MUSL}.tar.gz" /home/vscode/.cargo/bin && \
  fetch cargo-audit CARGO_AUDIT_SHA256 "https://github.com/rustsec/rustsec/releases/download/cargo-audit%2Fv${CARGO_AUDIT_VERSION}/cargo-audit-${ALT}-v${CARGO_AUDIT_VERSION}.tgz" /home/vscode/.cargo/bin && \
  fetch cargo-llvm-cov CARGO_LLVM_COV_SHA256 "https://github.com/taiki-e/cargo-llvm-cov/releases/download/v${CARGO_LLVM_COV_VERSION}/cargo-llvm-cov-${MUSL}.tar.gz" /home/vscode/.cargo/bin && \
  fetch cargo-machete CARGO_MACHETE_SHA256 "https://github.com/bnjbvr/cargo-machete/releases/download/v${CARGO_MACHETE_VERSION}/cargo-machete-v${CARGO_MACHETE_VERSION}-${ALT}.tar.gz" /home/vscode/.cargo/bin

# No usable prebuilts: bacon ships no release binaries at all, and
# cargo-mutants / cargo-vet publish no arm64 Linux builds, so these compile
# from crates.io, version-pinned and built against each crate's own lockfile.
ARG CARGO_MUTANTS_VERSION=27.1.0
ARG CARGO_VET_VERSION=0.10.0
ARG BACON_VERSION=3.24.0
RUN cargo install --locked "cargo-mutants@${CARGO_MUTANTS_VERSION}"
RUN cargo install --locked "cargo-vet@${CARGO_VET_VERSION}"
RUN cargo install --locked "bacon@${BACON_VERSION}"

# Below the Rust chain: CODEX_VERSION is the most-bumped pin, and above it a
# bump forced a rustup reinstall plus three source compiles.
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

# Verify the installer script by SHA-256 before executing it as root, rather
# than piping curl straight into a shell. Update on ZSH_IN_DOCKER_VERSION bumps.
ARG ZSH_IN_DOCKER_VERSION=1.2.1
ARG ZSH_IN_DOCKER_SHA256=0cf15b6f9c63a8103eb33bad87dc4b43fed0e0ad5884dff90f943ee1e868796e
RUN curl -fsSL "https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh" -o /tmp/zid.sh && \
  echo "${ZSH_IN_DOCKER_SHA256}  /tmp/zid.sh" | sha256sum -c - && \
  sh /tmp/zid.sh -p git -x && \
  rm /tmp/zid.sh

COPY --chown=vscode:vscode .zshrc /home/vscode/.zshrc.custom
RUN echo 'source ~/.zshrc.custom' >> /home/vscode/.zshrc

COPY --chown=vscode:vscode post_install.py /opt/post_install.py
COPY --chown=vscode:vscode --chmod=0755 post-start.sh /opt/post_start.sh
COPY --chmod=0500 init-firewall.sh /usr/local/bin/init-firewall.sh
COPY --chmod=0500 apply-firewall.sh /usr/local/bin/apply-firewall.sh

# The firewall allowlist is baked in as root-owned, world-unwritable files so
# the untrusted vscode agent cannot supply the payload the root applier acts on.
# Build args (not containerEnv) because the applier runs as root while PID 1
# runs as vscode: reading another uid's environ needs CAP_SYS_PTRACE, which this
# profile deliberately withholds. Keep this stanza last so editing the allowlist
# rebuilds only this layer. Bash expands the arg without rescanning it, so a
# value cannot inject build-time commands; contents are validated again at apply
# time. Profiles that pass no args get an empty list and must keep the firewall
# disabled, since the applier refuses to proceed without domains.
USER root
ARG AGENT_ALLOWED_DOMAINS=""
ARG AGENT_INCLUDE_GITHUB_META_RANGES=1
RUN install -d -m 0755 /etc/agent-devcontainer && \
  printf '%s\n' "$AGENT_ALLOWED_DOMAINS" > /etc/agent-devcontainer/allowed-domains.in && \
  printf '%s\n' "$AGENT_INCLUDE_GITHUB_META_RANGES" > /etc/agent-devcontainer/include-github-meta && \
  chmod 0444 /etc/agent-devcontainer/allowed-domains.in /etc/agent-devcontainer/include-github-meta
USER vscode
