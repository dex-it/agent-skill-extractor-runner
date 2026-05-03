# agent-skill-extractor-runner

Docker-образ для CI-runner'а проекта [`agent-skill-extractor`](https://git.dextechnology.com/mmx003/agent-skill-extractor) (живёт на private GitLab `git.dextechnology.com`).

Этот репозиторий существует только потому что у GitLab-инстанса нет работающего Container Registry. Сборка образа делается через GitHub Actions, образ публикуется в GitHub Container Registry, оттуда его pull'ит GitLab CI как `image:` для своих jobs.

## Что внутри образа

`debian:12-slim` плюс предустановленные CLI:

| Инструмент | Зачем |
|------------|-------|
| `vault` | JWT auth + чтение секретов из HashiCorp Vault (GitLab CE не поддерживает `secrets:` keyword) |
| `glab` | GitLab API (получить MR, оставить комментарий) |
| `gh` | GitHub API (создать PR в маркетплейс) |
| `claude-code` (`@anthropic-ai/claude-code`) | Анализ MR через Claude |
| `jq`, `yq` | Парсинг JSON/YAML |
| `git`, `nodejs`, `npm`, `curl`, `tar`, `unzip` | Базовое |

## Где лежит готовый образ

```
ghcr.io/dex-it/agent-skill-extractor-runner:latest
ghcr.io/dex-it/agent-skill-extractor-runner:<short-sha>
```

Package публичный — pull без аутентификации.

## Когда пересобирается

GitHub Actions workflow `.github/workflows/build.yml` запускается:
- автоматически при push в `main` с изменением `Dockerfile`
- вручную через `Actions` → `Build & publish runner image` → `Run workflow`

## Локальная сборка для отладки

```bash
docker build -t agent-skill-extractor-runner:dev .
docker run --rm -it agent-skill-extractor-runner:dev bash
# внутри:
vault --version
glab --version
gh --version
claude --version
```

## Как использует основной проект

В `.gitlab-ci.yml` репозитория `agent-skill-extractor`:

```yaml
analyze-recent-merges:
  image: ghcr.io/dex-it/agent-skill-extractor-runner:latest
  before_script:
    - vault write -field=token auth/jwt/login role=agent-skill-extractor jwt="$VAULT_ID_TOKEN"
    - export ANTHROPIC_API_KEY=$(vault kv get -field=ANTHROPIC_API_KEY backend/agent-skill-extractor/anthropic)
    # ...
  script:
    - ./scripts/poll-and-analyze.sh
```
