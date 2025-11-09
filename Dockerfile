# Build stage
FROM node:12.18.1-alpine as builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies
RUN npm ci --only=production

# Final stage
FROM node:12.18.1-alpine

# Create non-root user
RUN addgroup -S nodejs && adduser -S nodejs -G nodejs

# Set working directory
WORKDIR /app

# Copy from builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY . .

# Set ownership to non-root user
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -q --spider http://localhost:3000/api/v1/test || exit 1

# Start application
CMD ["npm", "start"]