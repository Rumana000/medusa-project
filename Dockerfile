FROM node:16-alpine

# 1. Install essentials
RUN apk add --no-cache git python3 make g++

# 2. Clone official starter
RUN git clone https://github.com/medusajs/medusa-starter-default /app

# 3. Install dependencies
WORKDIR /app
RUN npm install

# 4. Copy custom files (if any)
COPY . .

EXPOSE 9000

CMD ["medusa", "start"]