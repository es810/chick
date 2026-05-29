# Build API from monorepo root (Railway default root = repo root)
FROM node:20-alpine

WORKDIR /app

COPY server/package.json server/package-lock.json ./
RUN npm ci --omit=dev

COPY server/ .

ENV NODE_ENV=production
EXPOSE 3000

CMD ["npm", "start"]
