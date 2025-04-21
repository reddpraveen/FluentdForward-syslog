# Build stage
FROM registry.access.redhat.com/ubi8/nodejs-16:latest as build

# Add application user and set working directory
USER 0
RUN mkdir -p /app
WORKDIR /app

# Set memory limits to avoid crashes
ENV NODE_OPTIONS="--max-old-space-size=2048"
# Use fewer workers to reduce memory pressure
ENV npm_config_jobs=2

# Set proper permissions for the non-root user
RUN chown -R 1001:0 /app && \
    chmod -R g+w /app

# Switch to non-root user
USER 1001

# Copy package files for dependency installation
COPY --chown=1001:0 package*.json ./

# Use npm install instead of npm ci (which requires package-lock.json)
RUN npm install --no-fund --no-audit

# Copy the rest of the application
COPY --chown=1001:0 . .

# Build the application
RUN npm run build

# Production stage using NGINX
FROM registry.access.redhat.com/ubi8/nginx-118:latest

# Copy built assets from the build stage
COPY --from=build /app/build /usr/share/nginx/html

# Configure NGINX
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Ensure proper permissions for nginx
USER 0
RUN chmod -R g+w /usr/share/nginx/html && \
    chown -R 1001:0 /usr/share/nginx/html

# Switch to non-root user
USER 1001

# Expose port
EXPOSE 8080

# Run NGINX
CMD ["nginx", "-g", "daemon off;"] 