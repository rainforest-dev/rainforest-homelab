FROM node:24-alpine

ARG BOARD_USER=owner

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY entrypoint.mjs ./

RUN adduser -D -h /home/board "$BOARD_USER" \
  && mkdir -p /data /home/board/.config/board/local \
  && chown -R "$BOARD_USER" /data /home/board
USER $BOARD_USER
ENV HOME=/home/board

EXPOSE 4101 4748
CMD ["node", "entrypoint.mjs"]
