FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git jq tar gzip unzip xz-utils \
  && rm -rf /var/lib/apt/lists/*

# Node.js LTS — официальный бинарь. Debian-репо даёт Node 18, но context7-mcp
# (через undici) требует глобальный File из Node 20+ — иначе падает на старте
# с "ReferenceError: File is not defined". Tarball верифицируется по SHASUMS256.
RUN set -eux \
  && NODE_VERSION=$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version') \
  && cd /tmp \
  && curl -fsSLO "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz" \
  && curl -fsSLO "https://nodejs.org/dist/${NODE_VERSION}/SHASUMS256.txt" \
  && grep " node-${NODE_VERSION}-linux-x64.tar.xz$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-${NODE_VERSION}-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-${NODE_VERSION}-linux-x64.tar.xz" SHASUMS256.txt \
  && node --version && npm --version

# yq (mikefarah). checksums-файл хранит хеши в колонках; индекс SHA-256
# берём из checksums_hashes_order, чтобы не зависеть от порядка.
RUN set -eux \
  && cd /tmp \
  && BASE=https://github.com/mikefarah/yq/releases/latest/download \
  && curl -fsSL "${BASE}/yq_linux_amd64" -o yq \
  && curl -fsSL "${BASE}/checksums" -o yq_checksums \
  && curl -fsSL "${BASE}/checksums_hashes_order" -o yq_order \
  && IDX=$(($(grep -n '^SHA-256$' yq_order | cut -d: -f1) + 1)) \
  && WANT=$(grep '^yq_linux_amd64 ' yq_checksums | awk -v i="$IDX" '{print $i}') \
  && echo "${WANT}  yq" | sha256sum -c - \
  && install -m 0755 yq /usr/local/bin/yq \
  && rm yq yq_checksums yq_order

# glab — резолвим версию через GitLab API (permalink-схема больше не работает)
RUN set -eux \
  && GLAB_VERSION=$(curl -fsSL "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases?per_page=1" | jq -r '.[0].tag_name' | tr -d v) \
  && cd /tmp \
  && BASE="https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/packages/generic/glab/${GLAB_VERSION}" \
  && curl -fsSL "${BASE}/glab_${GLAB_VERSION}_linux_amd64.tar.gz" -o glab.tar.gz \
  && curl -fsSL "${BASE}/checksums.txt" -o glab_checksums.txt \
  && WANT=$(grep "glab_${GLAB_VERSION}_linux_amd64.tar.gz$" glab_checksums.txt | awk '{print $1}') \
  && echo "${WANT}  glab.tar.gz" | sha256sum -c - \
  && tar -xzf glab.tar.gz -C /tmp \
  && mv /tmp/bin/glab /usr/local/bin/glab \
  && rm -rf /tmp/bin glab.tar.gz glab_checksums.txt

# gh (latest release)
RUN set -eux \
  && GH_VERSION=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | jq -r .tag_name | tr -d v) \
  && cd /tmp \
  && BASE="https://github.com/cli/cli/releases/download/v${GH_VERSION}" \
  && curl -fsSL "${BASE}/gh_${GH_VERSION}_linux_amd64.tar.gz" -o gh.tar.gz \
  && curl -fsSL "${BASE}/gh_${GH_VERSION}_checksums.txt" -o gh_checksums.txt \
  && WANT=$(grep "gh_${GH_VERSION}_linux_amd64.tar.gz$" gh_checksums.txt | awk '{print $1}') \
  && echo "${WANT}  gh.tar.gz" | sha256sum -c - \
  && tar -xzf gh.tar.gz -C /tmp \
  && mv "/tmp/gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh \
  && rm -rf "/tmp/gh_${GH_VERSION}_linux_amd64" gh.tar.gz gh_checksums.txt

# vault CLI — для JWT->token обмена и чтения секретов в GitLab CE
# (GitLab CE не поддерживает `secrets:` keyword из .gitlab-ci.yml)
RUN set -eux \
  && VAULT_VERSION=$(curl -fsSL https://api.github.com/repos/hashicorp/vault/releases/latest | jq -r .tag_name | tr -d v) \
  && cd /tmp \
  && BASE="https://releases.hashicorp.com/vault/${VAULT_VERSION}" \
  && curl -fsSL "${BASE}/vault_${VAULT_VERSION}_linux_amd64.zip" -o vault.zip \
  && curl -fsSL "${BASE}/vault_${VAULT_VERSION}_SHA256SUMS" -o vault_SHA256SUMS \
  && WANT=$(grep "vault_${VAULT_VERSION}_linux_amd64.zip$" vault_SHA256SUMS | awk '{print $1}') \
  && echo "${WANT}  vault.zip" | sha256sum -c - \
  && unzip vault.zip -d /usr/local/bin \
  && rm vault.zip vault_SHA256SUMS

# claude-code (CLI). Плагин dex-knowledge-extractor ставится в runtime в poll-and-analyze.sh
RUN npm install -g @anthropic-ai/claude-code

# context7 MCP-сервер — предустановлен глобально (npx не докачивает его в CI)
# и зарегистрирован в user-scope конфиге claude (/root/.claude.json).
# Headless-claude подхватит его без настройки в основном проекте при HOME=/root.
# Версия запинена: tool-имена сервера (resolve-library-id / query-docs) зашиты в
# allowed-tools команды /mr-analyze маркетплейса. Плавающий latest при rename тула
# (в 3.x README уже расходился с кодом) молча сломал бы fact-check — пин держит
# контракт. Бамп версии = синхронная сверка имён тулов в mr-analyze.md.
RUN npm install -g @upstash/context7-mcp@3.2.0 \
  && claude mcp add context7 -s user -- context7-mcp

WORKDIR /work

CMD ["bash"]
