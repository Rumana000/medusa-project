# Use multi-stage build to reduce final image size
FROM node:16-alpine AS builder

# 1. Install build tools
RUN apk add --no-cache git python3 make g++

# 2. Clone official starter
RUN git clone https://github.com/medusajs/medusa-starter-default /app

# 3. Install dependencies
WORKDIR /app
COPY package*.json ./
RUN npm install

# --- Final Stage ---
FROM node:16-alpine

WORKDIR /app
# Copy only necessary files from builder
COPY --from=builder /app /app

# Copy custom files (if any)
COPY . .

EXPOSE 9000

CMD ["medusa", "start"]