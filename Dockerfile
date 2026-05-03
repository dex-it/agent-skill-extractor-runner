FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git jq nodejs npm tar gzip unzip \
  && rm -rf /var/lib/apt/lists/*

# yq (mikefarah)
RUN curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# glab
RUN curl -fsSL https://gitlab.com/gitlab-org/cli/-/releases/permalink/latest/downloads/glab_linux_amd64.tar.gz \
    | tar -xz -C /tmp \
  && mv /tmp/bin/glab /usr/local/bin/glab \
  && rm -rf /tmp/bin

# gh (latest release)
RUN GH_VERSION=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | jq -r .tag_name | tr -d v) \
  && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
    | tar -xz -C /tmp \
  && mv "/tmp/gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh \
  && rm -rf "/tmp/gh_${GH_VERSION}_linux_amd64"

# vault CLI — для JWT->token обмена и чтения секретов в GitLab CE
# (GitLab CE не поддерживает `secrets:` keyword из .gitlab-ci.yml)
RUN VAULT_VERSION=$(curl -fsSL https://api.github.com/repos/hashicorp/vault/releases/latest | jq -r .tag_name | tr -d v) \
  && curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" \
    -o /tmp/vault.zip \
  && unzip /tmp/vault.zip -d /usr/local/bin \
  && rm /tmp/vault.zip

# claude-code (CLI). Плагин dex-knowledge-extractor ставится в runtime в poll-and-analyze.sh
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /work

CMD ["bash"]
