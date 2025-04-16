# Build stage
FROM registry.access.redhat.com/ubi9/nodejs-18:latest as build

# Add application user and set working directory
USER 0
RUN mkdir -p /app
WORKDIR /app
USER 1001

# Copy package files for dependency installation
COPY --chown=1001:0 package*.json ./

# Install dependencies
RUN npm ci

# Copy the rest of the application
COPY --chown=1001:0 . .

# Build the application
RUN npm run build

# Production stage using NGINX
FROM registry.access.redhat.com/ubi9/nginx-120:latest

# Copy built assets from the build stage
COPY --from=build /app/build /usr/share/nginx/html

# Configure NGINX
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 8080

# Run NGINX
CMD ["nginx", "-g", "daemon off;"] 