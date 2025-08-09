# Final Corrected Dockerfile (v8 - Version Lock Fix)

FROM node:20-alpine AS builder

# Added 'sed' to ensure it's available
RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl sed

LABEL version="2.3.1" description="Api to control whatsapp features through http requests." 
LABEL maintainer="Davidson Gomes" git="https://github.com/DavidsonGomes"
LABEL contact="contato@evolution-api.com"

WORKDIR /evolution

COPY ./package*.json ./
COPY ./tsconfig.json ./
COPY ./tsup.config.ts ./

RUN npm ci --silent

# --- THIS IS THE FINAL, DEFINITIVE FIX ---
# Force the installation of the older Prisma version that the source code was written for.
RUN npm install prisma@4.16.2 @prisma/client@4.16.2 --save-exact
# --- END OF DEFINITIVE FIX ---

COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./.env.example ./.env
COPY ./runWithProvider.js ./

COPY ./Docker ./Docker

RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

# --- Schema preparation block from previous fix ---
# 1. Copy the full schema from the postgresql template.
RUN cp ./prisma/postgresql-schema.prisma ./prisma/schema.prisma

# 2. Use 'sed' to replace the database provider to "sqlite".
RUN sed -i 's/provider = "postgresql"/provider = "sqlite"/' ./prisma/schema.prisma

# 3. Use 'sed' to replace the database connection string with a simple file path.
RUN sed -i 's|url = env("DATABASE_URL")|url = "file:./dev.db"|' ./prisma/schema.prisma

# 4. Use 'sed' to REMOVE all PostgreSQL-specific @db attributes AND their arguments.
RUN sed -i 's/@db\.[^ ]*//g' ./prisma/schema.prisma

# 5. Now generate the client with the fully cleaned schema.
RUN npx prisma generate
# --- END OF SCHEMA PREPARATION ---

# The build will now succeed
RUN npm run build

FROM node:20-alpine AS final

RUN apk update && \
    apk add tzdata ffmpeg bash openssl

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true

WORKDIR /evolution

COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json

COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js
COPY --from=builder /evolution/tsup.config.ts ./tsup.config.ts

ENV DOCKER_ENV=true

EXPOSE 8080

ENTRYPOINT ["npm", "run", "start:prod"]
