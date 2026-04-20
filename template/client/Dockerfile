FROM node:22-alpine AS build
WORKDIR /app
# Use `npm install` rather than `npm ci` because the template's
# package-lock.json can drift from package.json across Angular minor
# upgrades. npm install tolerates the drift and regenerates the lock
# in-image; services that commit their own lockfile get deterministic
# builds via `npm ci` in CI.
COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund
COPY . .
RUN npx ng build --configuration docker

FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/client/browser /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
