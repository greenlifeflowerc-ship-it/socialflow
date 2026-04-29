# AutoFlow Backend

## Setup
1. `npm init -y`
2. `npm install express cors dotenv multer axios node-cron`
3. Create `.env` from `.env.example`
4. `node server.js`

## Endpoints
- `POST /api/upload`: Upload image
- `POST /api/gemini/generate-caption`: Generate AI caption
- `POST /api/meta/publish-now`: Immediate publish
- `GET /api/posts`: List posts
