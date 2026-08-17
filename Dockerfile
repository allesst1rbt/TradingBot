FROM node:26-bookworm-slim AS node_source

FROM hexpm/elixir:1.20.2-erlang-29.0.4-debian-trixie-20260713-slim

ENV MIX_ENV=prod
ENV HOME=/root
ENV PYTHONUNBUFFERED=1
ENV HERMES_HOME=/root/.hermes
ENV HERMES_DISABLE_LAZY_INSTALLS=1
ENV PATH="/root/.local/bin:${PATH}"
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git xz-utils libatomic1 ripgrep && rm -rf /var/lib/apt/lists/*

COPY --from=node_source /usr/local/bin/node /usr/local/bin/
COPY --from=node_source /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

COPY package.json /opt/tradingview/package.json
RUN npm install --prefix /opt/tradingview --omit=dev --no-audit --no-fund && \
    npx --prefix /opt/tradingview playwright install --with-deps chromium

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

RUN git clone --depth 1 https://github.com/NousResearch/hermes-agent /opt/hermes-agent

WORKDIR /opt/hermes-agent

RUN /root/.local/bin/uv sync --frozen --no-install-project --extra all --extra messaging \
 && /root/.local/bin/uv pip install --no-cache-dir --no-deps -e .

ENV PATH="/opt/hermes-agent/.venv/bin:${PATH}"

WORKDIR /app

COPY mix.exs mix.lock ./
RUN mix local.hex --force && mix deps.get --only prod

COPY . .

RUN MIX_ENV=prod mix compile

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["mix", "bot.daily"]
