# ---------- Stage 1: install production dependencies ----------
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev && npm cache clean --force

# ---------- Stage 2: minimal runtime ----------
FROM node:20-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json server.js ./
# run as the unprivileged "node" user that ships with the image
USER node
EXPOSE 3000
CMD ["node", "server.js"]
