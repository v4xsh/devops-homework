# ---------- Stage 1: build the static bundle with Node ----------
FROM node:20-alpine AS build
WORKDIR /app

# Install dependencies (cached while package.json is unchanged)
COPY package*.json ./
RUN npm install

# Copy the source and produce the production build in /app/dist
COPY . .
RUN npm run build

# ---------- Stage 2: serve the static files with Nginx ----------
FROM nginx:alpine

# SPA-friendly nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Only the compiled files are copied; node, node_modules and sources are discarded
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
