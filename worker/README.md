# Myaarchive Cloudflare Worker API

Secure backend proxy and asset gateway for Myaarchive (Mobile & Desktop).

## Key Responsibilities

1. **Secrets Isolation**: The Turso read-write JWT token and R2 access keys are stored securely on Cloudflare Workers and **never bundled** into client binaries.
2. **Authentication & JWT**:
   - `POST /api/auth/signup`: Creates account, hashes passwords with bcrypt, seeds initial user library & statuses, mints JWT.
   - `POST /api/auth/signin`: Verifies credentials, mints 30-day session JWT.
   - `GET /api/auth/me`: Verifies active user session.
   - `POST /api/auth/change-password`: Changes password with current password verification.
   - `GET /api/auth/security-question`: Retrieves security question for password recovery.
   - `POST /api/auth/reset-password`: Resets password via security answer.
   - `POST /api/auth/delete-account`: Verifies password first, wipes all user data in a single atomic transaction, sweeps R2 assets, and deletes account.
3. **Asset Handling (Cloudflare R2)**:
   - Direct integration via Cloudflare Workers `env.BUCKET` binding (`myaarchive-assets`).
   - `POST /api/assets/upload?prefix=covers`: Authenticated upload of raw image bytes (JPEG/PNG/WebP/GIF, max 10 MB). The server picks the key, always under `u/<userId>/<prefix>/`.
   - `GET /api/assets/presign-download?key=...`: Authenticated; returns a time-limited signed link (`exp` + `sig`) for one object. Only the owner can sign a `u/<userId>/` key.
   - `GET /api/assets/<key>?exp=...&sig=...`: Streams the object. Requires a valid, unexpired signature.
   - `DELETE /api/assets/<key>`: Authenticated; only the owner's own `u/<userId>/` objects can be deleted.
   - Keys created before per-user scoping (e.g. `covers/<uuid>.jpg`) can still be signed for reading but not deleted through the API. Migrate them, then drop the legacy allowance in `routes/assets.ts`.
4. **Data Query Proxying**:
   - `POST /api/db/pipeline` (transitional): Authenticated Turso Hrana v2 proxy. Blocks the `users` table, DDL escape hatches and multi-statement requests. It does **not** enforce per-user row ownership; replace it with owner-checked routes.
   - `/api/data/*`: Server-side owner-enforced REST routes for libraries, tags, statuses, and app settings.

---

## Getting Started

### 1. Install Dependencies

```bash
cd worker
npm install
```

### 2. Configure Cloudflare Secrets

Set your Turso auth token and JWT signing secret in Cloudflare:

```bash
# Set your Turso master auth token
npx wrangler secret put TURSO_AUTH_TOKEN

# Set your JWT signing secret
npx wrangler secret put JWT_SECRET
```

For local development, create a `.dev.vars` file in the `worker/` directory:

```env
TURSO_DB_URL=libsql://myaarchive-maomao.aws-ap-northeast-1.turso.io
TURSO_AUTH_TOKEN=your_turso_token_here
JWT_SECRET=your_local_jwt_secret_here
```

### 3. Run Locally

```bash
npm run dev
# Starts local worker dev server at http://localhost:8787
```

### 4. Deploy to Cloudflare Workers

```bash
npm run deploy
```
