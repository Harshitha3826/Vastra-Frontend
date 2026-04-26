# Stage 1: Build the React Application
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm install

# Copy your source code and build it
COPY . .
RUN npm run build

# Stage 2: Serve the built app using Nginx
FROM nginx:alpine

# IMPORTANT: If you created your React app with Vite, change `/app/build` to `/app/dist`
COPY --from=builder /app/dist /usr/share/nginx/html

# The standard Nginx port (matches our Helm configuration perfectly)
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
