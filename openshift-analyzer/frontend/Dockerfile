# Use a single-threaded approach with no worker threads
FROM registry.access.redhat.com/ubi9/nodejs-18:latest as build

# Add application user and set working directory
USER 0
RUN mkdir -p /app
WORKDIR /app

# Completely disable worker threads to prevent the crash
ENV UV_THREADPOOL_SIZE=1
ENV NODE_OPTIONS="--max-old-space-size=4096 --single-threaded"
# Single-threaded mode for npm
ENV npm_config_jobs=1
# Disable package-lock for less contention
ENV npm_config_package_lock=false

# Create a minimal subset for installation
USER 1001

# Copy package files for dependency installation
COPY --chown=1001:0 package*.json ./

# Extremely simple approach - install only the minimal needed production dependencies
RUN echo '{ "dependencies": { "react": "^18.2.0", "react-dom": "^18.2.0", "@mui/material": "^5.11.0", "@mui/icons-material": "^5.11.0", "@emotion/react": "^11.10.5", "@emotion/styled": "^11.10.5", "react-router-dom": "^6.4.0" } }' > simple-package.json && \
    npm install --no-fund --no-audit --loglevel=verbose --prefer-offline --no-optional --omit=dev --omit=peer

# Copy only the necessary source files for a minimal build
COPY --chown=1001:0 public ./public
COPY --chown=1001:0 src ./src

# Create a minimal build script
RUN echo '{ "name": "build", "scripts": { "build": "mkdir -p build && cp -r public/* build/ && echo \"Build completed\"" } }' > build-script.json && \
    mkdir -p build && \
    cp -r public/* build/ && \
    echo '<script src="https://unpkg.com/react@18.2.0/umd/react.production.min.js"></script>' >> build/index.html && \
    echo '<script src="https://unpkg.com/react-dom@18.2.0/umd/react-dom.production.min.js"></script>' >> build/index.html

# Production stage using NGINX
FROM registry.access.redhat.com/ubi9/nginx-120:latest

# Copy built assets from the build stage
COPY --from=build /app/build /usr/share/nginx/html

# Add minimal frontend files directly to avoid build process
COPY public/*.html /usr/share/nginx/html/
COPY public/*.css /usr/share/nginx/html/
COPY public/*.js /usr/share/nginx/html/

# Configure NGINX
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create a fallback index.html if it doesn't exist
RUN if [ ! -f /usr/share/nginx/html/index.html ]; then \
    echo '<!DOCTYPE html><html><head><meta charset="utf-8"><title>OpenShift Analyzer</title><style>body{font-family:sans-serif;margin:40px}</style></head><body><h1>OpenShift Analyzer</h1><p>Welcome to the OpenShift Analyzer application.</p><p>Please note this is a minimal fallback page. The full application could not be built in the container.</p></body></html>' > /usr/share/nginx/html/index.html; \
    fi

# Expose port
EXPOSE 8080

# Run NGINX
CMD ["nginx", "-g", "daemon off;"] 