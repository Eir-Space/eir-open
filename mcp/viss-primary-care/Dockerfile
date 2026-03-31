FROM node:22-slim

ENV NODE_ENV=production
ENV PORT=8080

WORKDIR /app

COPY mcp/viss-primary-care/package*.json ./mcp/viss-primary-care/
RUN cd mcp/viss-primary-care && npm ci --omit=dev

COPY mcp/viss-primary-care/server*.js /app/mcp/viss-primary-care/
COPY mcp/viss-primary-care/README.md /app/mcp/viss-primary-care/
COPY skills/viss-primary-care /app/skills/viss-primary-care

WORKDIR /app/mcp/viss-primary-care

EXPOSE 8080

CMD ["node", "server-http.js"]
