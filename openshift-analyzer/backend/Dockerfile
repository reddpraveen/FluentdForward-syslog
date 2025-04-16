FROM registry.access.redhat.com/ubi9/python-311:latest

# Add application user
USER 0
RUN mkdir -p /app /app/config /app/plugins && \
    chown -R 1001:0 /app && \
    chmod -R g=u /app
USER 1001

# Set working directory
WORKDIR /app

# Copy requirements first for better layer caching
COPY --chown=1001:0 requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY --chown=1001:0 . .

# Create necessary directories with proper permissions
RUN mkdir -p /app/logs && \
    chmod -R g=u /app/logs

# Expose port
EXPOSE 8080

# Command to run the application
CMD ["python", "main.py"] 