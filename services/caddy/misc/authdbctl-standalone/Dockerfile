FROM golang:alpine AS builder

RUN apk add --no-cache git

RUN go install github.com/greenpau/go-authcrunch/cmd/authdbctl@latest

FROM alpine:latest AS runner

COPY --from=builder /go/bin/authdbctl /usr/local/bin/authdbctl

ENTRYPOINT ["authdbctl"]