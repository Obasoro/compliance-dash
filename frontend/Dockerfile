# Build stage
FROM node:18-alpine as build

# Create app directory
WORKDIR /app

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Copy package files first for better caching
COPY package.json package-lock.json* ./

# Install dependencies
RUN npm ci --only=production --ignore-scripts

# Copy source code
COPY . .

# Change ownership to non-root user
RUN chown -R nextjs:nodejs /app
USER nextjs

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create non-root user for nginx
RUN addgroup -g 1001 -S nginx && \
    adduser -S nginx -u 1001 -G nginx

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built static files from build stage
COPY --from=build --chown=nginx:nginx /app/build /usr/share/nginx/html

# Create nginx cache and log directories with proper permissions
RUN mkdir -p /var/cache/nginx /var/log/nginx /var/run && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx /var/run /usr/share/nginx/html

# Switch to non-root user
USER nginx

# Expose port 3000
EXPOSE 3000

# Use dumb-init to handle signals properly and run nginx in foreground
CMD ["dumb-init", "nginx", "-g", "daemon off;"]