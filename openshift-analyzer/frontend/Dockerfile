# Build stage
FROM registry.access.redhat.com/ubi9/nodejs-18:latest as build

# Add application user and set working directory
USER 0
RUN mkdir -p /app
# Add more memory for node
RUN echo "node --max-old-space-size=4096 \"\$@\"" > /usr/bin/node-large && chmod +x /usr/bin/node-large
WORKDIR /app
USER 1001

# Increase NODE memory limits significantly and reduce concurrency
ENV NODE_OPTIONS="--max-old-space-size=4096"
# Use a single thread for more stability but slower builds
ENV npm_config_jobs=1

# Copy package files for dependency installation
COPY --chown=1001:0 package*.json ./

# Break down installation to reduce memory pressure - serial mode with no extras
RUN npm install --no-fund --no-audit --prefer-offline --no-optional --legacy-peer-deps || \
    # If it fails, retry with a more cautious approach
    npm install --no-fund --no-audit --prefer-offline --production --no-optional --legacy-peer-deps && \
    npm install --no-fund --no-audit --prefer-offline --only=dev --no-optional --legacy-peer-deps

# Copy the rest of the application
COPY --chown=1001:0 . .

# Build the application - if build fails due to memory, use node-large
RUN npm run build || \
    NODE_OPTIONS="--max-old-space-size=4096" /usr/bin/node-large ./node_modules/.bin/react-scripts build

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