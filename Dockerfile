FROM golang:1.25.1-alpine AS builder

RUN apk add --no-cache \
    git \
    ca-certificates \
    tzdata

ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux

ARG TARGETARCH
ENV GOARCH=$TARGETARCH

RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

RUN xcaddy build \
    --with github.com/tailscale/caddy-tailscale \
    --with github.com/caddyserver/forwardproxy


FROM alpine:3.19

RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    mailcap

RUN addgroup -g 1000 caddy && \
    adduser -D -s /bin/sh -u 1000 -G caddy caddy

COPY --from=builder /caddy /usr/bin/caddy
RUN chmod +x /usr/bin/caddy

RUN mkdir -p /etc/caddy /var/lib/caddy /var/log/caddy /config && \
    chown -R caddy:caddy /etc/caddy /var/lib/caddy /var/log/caddy /config

USER caddy

EXPOSE 80 443 2019

WORKDIR /etc/caddy

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD caddy version || exit 1

CMD ["caddy", "run", "--config", "/config/Caddyfile", "--adapter", "caddyfile"]
