FROM node:22-alpine AS build
WORKDIR /app
# `npm install` rather than `npm ci`: the template ships no lockfile, so a
# scaffolded service resolves fresh. Services that commit their own
# package-lock.json should switch this to `npm ci` for deterministic builds.
COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund
COPY . .
RUN npm run build

FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
