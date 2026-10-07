# Small official Node.js runtime based on Alpine Linux
FROM node:20-alpine

# All following commands run inside /app
WORKDIR /app

# Copy only the dependency manifest first so the "npm install" layer is cached
# as long as package.json does not change
COPY package*.json ./
RUN npm install --omit=dev

# Copy the application source
COPY server.js ./

# Documents the port the app listens on (does not publish it)
EXPOSE 3000

# Start the server
CMD ["node", "server.js"]
