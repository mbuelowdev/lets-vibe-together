# syntax=docker/dockerfile:1

FROM debian:bookworm-slim AS export

ARG GODOT_VERSION=4.7.2
ARG GODOT_STATUS=stable

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl libfontconfig1 unzip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/godot.zip \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_STATUS}/Godot_v${GODOT_VERSION}-${GODOT_STATUS}_linux.x86_64.zip" \
    && curl -fsSL -o /tmp/templates.tpz \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_STATUS}/Godot_v${GODOT_VERSION}-${GODOT_STATUS}_export_templates.tpz" \
    && unzip -q /tmp/godot.zip -d /tmp \
    && mv "/tmp/Godot_v${GODOT_VERSION}-${GODOT_STATUS}_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && mkdir -p "/root/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_STATUS}" \
    && unzip -q /tmp/templates.tpz "templates/version.txt" "templates/web_*.zip" -d /tmp \
    && mv /tmp/templates/* "/root/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_STATUS}/" \
    && rm -rf /tmp/godot.zip /tmp/templates.tpz /tmp/templates

WORKDIR /src
COPY . .

RUN mkdir -p /out \
    && godot --headless --path /src --import \
    && godot --headless --path /src --export-release Web /out/index.html \
    && test -f /out/index.html \
    && test -f /out/index.wasm \
    && test -f /out/index.pck

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
RUN rm -rf /usr/share/nginx/html/*
COPY --from=export /out /usr/share/nginx/html

EXPOSE 80
