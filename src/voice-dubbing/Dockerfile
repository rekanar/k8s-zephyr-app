FROM node:20-alpine

WORKDIR /app

COPY package.json .
RUN npm install --omit=dev

COPY . .

# Recordings persist here — mount a volume in production
RUN mkdir -p recordings

EXPOSE 3000

ENV NODE_ENV=production

CMD ["node", "server.js"]
