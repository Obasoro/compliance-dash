# Backend

Node.js backend for the NIST-800 Compliance Dashboard.

- TypeScript, Express, Prisma ORM
- Integrates AWS SDK v3 and OpenAI API

## Setup
1. `npm install`
2. Configure `.env` (see `.env.example`)
3. `npx prisma migrate dev`
4. `npm run dev`

# Test
1. docker build -t obasoro/compliance-dash .
2. docker run -d -p 4000:4000 obasoro/compliance-dash
3. http://localhost:4000
