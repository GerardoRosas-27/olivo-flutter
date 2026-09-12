# Multi-stage: Flutter web build, then Express serving web + APK on Railway
FROM ghcr.io/gmeligio/flutter-web:3.47.2 AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter config --enable-web && flutter pub get

COPY . .
RUN flutter build web --release --base-href /

FROM node:20-alpine

WORKDIR /app

RUN apk add --no-cache curl zip

COPY server/package.json ./
RUN npm i --omit=dev

COPY server/server.js ./
COPY server/fetch_apk.sh ./fetch_apk.sh
COPY server/install_notes ./install_notes

COPY --from=build /app/build/web ./public

RUN chmod +x fetch_apk.sh && ./fetch_apk.sh

ENV PORT=8080
EXPOSE 8080

CMD ["node", "server.js"]
