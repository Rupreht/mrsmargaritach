# syntax=docker/dockerfile:1.7
#
# Мультистадийная сборка сайта «Маргарита Чистова».
#
#   tools    — тулчейн CI (Hugo extended, Dart Sass, Python + yamllint, Node,
#              lychee, Task). Используется для `hugo server` и ручных проверок.
#   builder  — собирает сайт: scripts/build.sh dist (основной сайт + города).
#   test     — builder + Chromium: полный прогон проверок ci.yml в контейнере.
#   nginx    — финальный лёгкий образ: только статика и конфиг nginx.
#
# Сборка:
#   docker build -t mrsmargaritach:local .              # финальный nginx
#   docker build --target test -t mrsmargaritach:test .  # проверки
#   docker build --target tools -t mrsmargaritach:tools .
#
# Версии закреплены, загрузки проверяются по SHA256 из checksums-файлов релизов.

ARG DEBIAN_RELEASE=bookworm

# ---------------------------------------------------------------------------
# tools: тулчейн, повторяющий шаги ci.yml
# ---------------------------------------------------------------------------
FROM debian:${DEBIAN_RELEASE}-slim AS tools

ARG TARGETARCH
ARG HUGO_VERSION=0.170.1
ARG DART_SASS_VERSION=1.108.2
ARG NODE_VERSION=22.23.5
ARG LYCHEE_VERSION=lychee-v0.24.2
ARG TASK_VERSION=3.54.0

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# yamllint и python3-yaml берутся из Debian: PyPI не нужен, сборка без pip.
# findutils/coreutils нужны scripts/build.sh (find/wc) и docker/check.sh.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        coreutils \
        curl \
        findutils \
        git \
        gzip \
        python3 \
        python3-yaml \
        tar \
        xz-utils \
        yamllint \
    && rm -rf /var/lib/apt/lists/*


# Hugo extended: `hugo` в PATH. Extended — требование проекта
# (docs/implementation_plan.md, п. 2.7), SCSS собирает внешний dart-sass.
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) arch=amd64 ;; \
        arm64) arch=arm64 ;; \
        *) echo "Неподдерживаемая архитектура: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    work="$(mktemp -d)"; cd "$work"; \
    base="https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}"; \
    curl -fsSL -O "${base}/hugo_${HUGO_VERSION}_checksums.txt"; \
    curl -fsSL -O "${base}/hugo_extended_${HUGO_VERSION}_linux-${arch}.tar.gz"; \
    grep " hugo_extended_${HUGO_VERSION}_linux-${arch}.tar.gz\$" \
        "hugo_${HUGO_VERSION}_checksums.txt" | sha256sum -c -; \
    tar -xzf "hugo_extended_${HUGO_VERSION}_linux-${arch}.tar.gz" hugo; \
    install -m 0755 hugo /usr/local/bin/hugo; \
    cd /; rm -rf "$work"; \
    hugo version


# Dart Sass: бинарник `sass`, который ищет Hugo Pipes.
# У релизов dart-sass нет checksums-файла — хэши закреплены по архитектуре.
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) arch=x64; sha=32d2eb5b83cbc180fce9657ff3c57401a9006c59eccfe0bfdde0aa755a66d42f ;; \
        arm64) arch=arm64; sha=1c7a587c81467e8f7551d71e5d62845b53270033c5cc3d36aa8fa07330a5d2a9 ;; \
        *) echo "Неподдерживаемая архитектура: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    work="$(mktemp -d)"; cd "$work"; \
    curl -fsSL -o dart-sass.tar.gz \
        "https://github.com/sass/dart-sass/releases/download/${DART_SASS_VERSION}/dart-sass-${DART_SASS_VERSION}-linux-${arch}.tar.gz"; \
    echo "${sha}  dart-sass.tar.gz" | sha256sum -c -; \
    mkdir -p /opt; \
    tar -xzf dart-sass.tar.gz -C /opt; \
    cd /; rm -rf "$work"; \
    /opt/dart-sass/sass --version

# Dart Sass — wrapper `sass` + src/dart, поэтому каталог целиком в PATH.
ENV PATH="/opt/dart-sass:${PATH}"

# Node.js 22: html-validate и @lhci/cli. Сам сайт по-прежнему собирается без Node.
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) arch=x64 ;; \
        arm64) arch=arm64 ;; \
        *) echo "Неподдерживаемая архитектура: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    work="$(mktemp -d)"; cd "$work"; \
    base="https://nodejs.org/dist/v${NODE_VERSION}"; \
    curl -fsSL -O "${base}/SHASUMS256.txt"; \
    curl -fsSL -O "${base}/node-v${NODE_VERSION}-linux-${arch}.tar.xz"; \
    grep " node-v${NODE_VERSION}-linux-${arch}.tar.xz\$" SHASUMS256.txt | sha256sum -c -; \
    tar -xJf "node-v${NODE_VERSION}-linux-${arch}.tar.xz" -C /usr/local --strip-components=1 \
        --exclude CHANGELOG.md --exclude LICENSE --exclude README.md; \
    cd /; rm -rf "$work"; \
    node --version; npm --version

# lychee (проверка ссылок, workflow links.yml) и Task (Taskfile.yaml).
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) lychee_arch=x86_64-unknown-linux-gnu; task_arch=amd64 ;; \
        arm64) lychee_arch=aarch64-unknown-linux-gnu; task_arch=arm64 ;; \
        *) echo "Неподдерживаемая архитектура: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    work="$(mktemp -d)"; cd "$work"; \
    lychee_base="https://github.com/lycheeverse/lychee/releases/download/${LYCHEE_VERSION}"; \
    curl -fsSL -O "${lychee_base}/lychee-${lychee_arch}.tar.gz"; \
    curl -fsSL -O "${lychee_base}/lychee-${lychee_arch}.tar.gz.sha256"; \
    sha256sum -c "lychee-${lychee_arch}.tar.gz.sha256"; \
    tar -xzf "lychee-${lychee_arch}.tar.gz"; \
    install -m 0755 "lychee-${lychee_arch}/lychee" /usr/local/bin/lychee; \
    task_base="https://github.com/go-task/task/releases/download/v${TASK_VERSION}"; \
    curl -fsSL -O "${task_base}/task_checksums.txt"; \
    curl -fsSL -O "${task_base}/task_linux_${task_arch}.tar.gz"; \
    grep " task_linux_${task_arch}.tar.gz\$" task_checksums.txt | sha256sum -c -; \
    tar -xzf "task_linux_${task_arch}.tar.gz" task; \
    install -m 0755 task /usr/local/bin/task; \
    cd /; rm -rf "$work"; \
    lychee --version; task --version; yamllint --version

ENV HUGO_CACHEDIR=/tmp/hugo-cache \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false

# Скрипт `dev` — запуск hugo server с понятной диагностикой, если каталог
# проекта не смонтирован (Colima без общих каталогов, Docker Desktop без
# file sharing).
COPY docker/dev.sh /usr/local/bin/dev
RUN chmod 0755 /usr/local/bin/dev

WORKDIR /site

# ---------------------------------------------------------------------------
# builder: мультисборка основного сайта и городских поддоменов
# ---------------------------------------------------------------------------
FROM tools AS builder

# baseURL сборки. Для локального превью — http://localhost:8080/,
# для образа «как в проде» — https://stilgrad.ru/ (значение по умолчанию).
ARG HUGO_BASE_URL=https://stilgrad.ru/

COPY . .

RUN bash scripts/build.sh dist "${HUGO_BASE_URL}"

# ---------------------------------------------------------------------------
# test: те же проверки, что в ci.yml (+ Lighthouse по запросу)
# ---------------------------------------------------------------------------
FROM builder AS test

# Chromium нужен Lighthouse CI; --no-sandbox уже задан в .lighthouserc.cjs.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        chromium \
        fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

ENV CHROME_PATH=/usr/bin/chromium \
    LHCI_STATIC_DIST_DIR=dist

COPY docker/check.sh /usr/local/bin/check
RUN chmod 0755 /usr/local/bin/check

CMD ["check"]

# ---------------------------------------------------------------------------
# nginx: финальный образ — только статика и конфиг.
# alpine-slim — nginx без динамических модулей: заметно меньше полного alpine.
# ---------------------------------------------------------------------------
FROM nginx:stable-alpine-slim AS nginx

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/site-common.conf /etc/nginx/snippets/site-common.conf
COPY --from=builder /site/dist /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q --spider http://127.0.0.1/ || exit 1

STOPSIGNAL SIGQUIT
