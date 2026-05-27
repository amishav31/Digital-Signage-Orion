# PROJECT_MEMORY.md — Digital-Signage-Orion (Orion Platform)

> **Purpose:** This file is a complete, self-contained reference for any AI model or developer joining this project. Read this file first. Everything you need to understand the product, architecture, data model, API surface, data flows, and conventions is here.

---

## 1. What Is Orion?

Orion is a **multi-tenant SaaS digital-signage CMS** (Content Management System). Customers ("Organizations / Tenants") log in to a web dashboard, upload media, build campaigns and playlists, and push that content to physical Android-based display screens (players). Platform operators (Orion internal team) manage tenants from a separate portal.

### Core Capabilities

| Feature | Description |
|---|---|
| **Asset Library** | Upload images, videos, PDFs, HTML files to AWS S3 |
| **Campaigns** | Curated sequences of assets with per-asset display durations |
| **Playlists** | Ordered collections of campaigns, assignable to devices |
| **Schedule** | Day-of-week + time-range rules for when a campaign runs |
| **Tickers** | Scrolling text overlays with speed, style, color, priority |
| **Devices** | Registered Android player screens with live telemetry |
| **Proof of Play (PoP)** | Audit trail of what played on which device and whether it succeeded |
| **Team & Permissions** | Per-user role + per-feature granular access inside each org |
| **Audit Log** | Every significant action recorded |
| **Platform Portal** | Orion-internal dashboard for managing tenant organizations |

---

## 2. Monorepo Layout

```
Digital-Signage-Orion/            ← npm workspaces monorepo root
├── apps/
│   ├── api/                      ← NestJS 11 REST API (port 3001)
│   ├── web/                      ← Next.js 16 dashboard (port 3000)
│   └── worker/                   ← BullMQ worker scaffold (not yet wired)
├── packages/
│   ├── types/                    ← Shared TypeScript types / SDK contract
│   ├── sdk/                      ← Client SDK helpers
│   ├── ui/                       ← Shared UI primitives
│   └── config/                   ← Shared ESLint / TS config
├── prisma/
│   ├── schema.prisma             ← Single source of truth for the database
│   ├── migrations/               ← Prisma-managed SQL migration history
│   └── seed.ts                   ← Demo data seeder
├── package.json                  ← Root scripts + workspace definition
├── PROJECT_GUIDE.md              ← Developer deep-dive guide
├── ANDROID_PLAYER_PROMPT.md      ← Android app build guide + API contracts
└── PROJECT_MEMORY.md             ← THIS FILE (AI model context)
```

Root `package.json` defines workspaces: `apps/*` and `packages/*`.

---

## 3. Technology Stack

| Layer | Technology |
|---|---|
| **Frontend** | Next.js 16 (App Router, Turbopack), React 19, Framer Motion, Lucide icons, `react-hot-toast`, `socket.io-client` |
| **Backend** | NestJS 11 on Express; global `/api` prefix; global `ValidationPipe`; `cors: true` |
| **Auth** | JWT (`@nestjs/jwt`) with bcrypt-hashed passwords; 12h token expiry; `JwtAuthGuard` on protected routes |
| **ORM / DB** | Prisma 6 + PostgreSQL 14+ |
| **Storage** | AWS S3 (presigned PUT for uploads, presigned GET for downloads) via `@aws-sdk/client-s3` + `s3-request-presigner` |
| **Realtime** | `socket.io-client` on the web side (server channel TBD) |
| **Tooling** | TypeScript 5, ESLint 9, Prisma CLI, NestJS CLI, `tsx` for seeds |
| **Android Player** | Kotlin, Jetpack Compose, ExoPlayer, Retrofit + OkHttp, Hilt, Room, EncryptedSharedPreferences |

---

## 4. Environment Variables

### `apps/api/.env` (Backend)

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string (Prisma) |
| `JWT_SECRET` | Signing secret for user auth JWTs |
| `PORT` | API port (default: `3001`) |
| `S3_BUCKET` | AWS S3 bucket name |
| `S3_REGION` | AWS region (e.g., `ap-south-1`) |
| `S3_ACCESS_KEY_ID` | IAM user access key |
| `S3_SECRET_ACCESS_KEY` | IAM user secret |
| `S3_ENDPOINT` | Optional: set for MinIO or path-style (e.g., `https://s3.ap-south-1.amazonaws.com`) |
| `S3_FORCE_PATH_STYLE` | Optional: `true` when using endpoint + path-style (MinIO or DNS fallback) |
| `ASSET_UPLOAD_DIR` | Optional legacy local dir mounted at `/uploads/*` (default: `tmp/uploads`) |

### `apps/web/.env.local` (Frontend)

| Variable | Purpose |
|---|---|
| `NEXT_PUBLIC_API_URL` | Full API base URL, e.g. `http://localhost:3001` (falls back to `http://localhost:3001` if unset) |

### Root `.env`

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | Used only by Prisma CLI commands run from repo root |

---

## 5. Local Development

```bash
# One-time setup
npm install
cp apps/api/.env.example apps/api/.env  # then fill in DATABASE_URL, JWT_SECRET, S3_*
npx prisma db push           # apply schema to DB
npm run db:seed              # seed demo data

# Daily dev
npm run dev:web              # Next.js → http://127.0.0.1:3000
npm run dev:api              # NestJS  → http://localhost:3001/api

# Other useful scripts
npm run db:migrate           # create a new Prisma migration
npm run db:reset             # reset DB + re-run migrations
npm run prisma:generate      # regenerate Prisma client after schema changes
npm run build:web | build:api
npm run lint:web
```

### Demo Accounts (seeded by `prisma/seed.ts`)

| Role | Email | Password |
|---|---|---|
| Super Admin | `admin@orion.dev` | `admin123` |
| Org Admin (Acme) | `orgadmin@acme.com` | `orgadmin123` |
| Content Editor (Acme) | `editor@acme.com` | `editor123` |
| Analyst Viewer (Acme) | `viewer@acme.com` | `viewer123` |

Login URL: `http://127.0.0.1:3000/login`
- Platform operators → `/platform`
- Tenant users → `/app`

---

## 6. Database Schema (Prisma)

All models live in `prisma/schema.prisma`. PostgreSQL is the provider.

### 6.1 Enums

| Enum | Values |
|---|---|
| `PlatformRole` | `SUPER_ADMIN`, `PLATFORM_ADMIN`, `SALES`, `SUPPORT` |
| `OrganizationRole` | `ORG_ADMIN`, `MANAGER`, `CONTENT_EDITOR`, `ANALYST_VIEWER` |
| `FeatureKey` | `DASHBOARD`, `ASSETS`, `PLAYLISTS`, `CAMPAIGNS`, `SCHEDULE`, `TICKERS`, `DEVICES`, `REPORTS`, `TEAM`, `SETTINGS` |
| `FeatureAccessLevel` | `NONE`, `VIEW`, `EDIT`, `MANAGE`, `CONTROL` |
| `UserStatus` | `ACTIVE`, `INVITED`, `SUSPENDED` |
| `OrganizationStatus` | `DRAFT`, `ACTIVE`, `SUSPENDED` |
| `MembershipStatus` | `ACTIVE`, `INVITED`, `SUSPENDED` |
| `InvitationStatus` | `PENDING`, `ACCEPTED`, `EXPIRED`, `REVOKED` |
| `InvitationScope` | `ORGANIZATION` |
| `CampaignStatus` | `ACTIVE`, `DRAFT`, `SCHEDULED` |
| `PlaylistStatus` | `ACTIVE`, `PAUSED`, `DRAFT` |
| `DeviceStatus` | `ONLINE`, `OFFLINE`, `WARNING` |
| `TickerSpeed` | `SLOW`, `NORMAL`, `FAST` |
| `TickerStyle` | `CLASSIC`, `NEON`, `GRADIENT`, `MINIMAL` |
| `TickerStatus` | `ACTIVE`, `PAUSED`, `DRAFT` |
| `TickerPriority` | `LOW`, `NORMAL`, `URGENT` |
| `ScheduleStatus` | `SCHEDULED`, `ACTIVE`, `COMPLETED`, `PAUSED` |
| `SchedulePriority` | `LOW`, `NORMAL`, `HIGH` |
| `ProofOfPlayStatus` | `VERIFIED`, `FAILED` |
| `AssetType` | `IMAGE`, `VIDEO`, `HTML`, `DOCUMENT` |
| `AssetStatus` | `UPLOADING`, `READY`, `ERROR` |

### 6.2 Models

#### `User`
```
id            String  (CUID, PK)
email         String  (unique)
fullName      String
passwordHash  String
platformRole  PlatformRole?   (null = pure tenant user)
status        UserStatus      (default: ACTIVE)
createdAt, updatedAt
─── Relations ───
memberships     → OrganizationMembership[]
sentInvitations → Invitation[] ("InvitationSender")
uploadedAssets  → Asset[]     ("AssetUploader")
auditLogs       → AuditLog[]  ("AuditActor")
```

#### `Organization`
```
id                  String  (CUID, PK)
name                String
slug                String  (unique)
status              OrganizationStatus  (default: DRAFT)
primaryContactName  String?
primaryContactEmail String?
salesNotes          String?
createdAt, updatedAt
─── Relations (all cascade-deleted with org) ───
memberships, invitations, assets, campaigns, playlists,
scheduleEvents, devices, tickers, proofOfPlayLogs, auditLogs
```

#### `OrganizationMembership`
```
id             String (CUID, PK)
userId         String
organizationId String
role           OrganizationRole
status         MembershipStatus (default: ACTIVE)
invitedById    String?
createdAt, updatedAt
─── Unique: (userId, organizationId) ───
─── Relations ───
user         → User
organization → Organization
permissions  → MembershipFeaturePermission[]
```

#### `MembershipFeaturePermission`
```
id           String (CUID, PK)
membershipId String
featureKey   FeatureKey
accessLevel  FeatureAccessLevel
createdAt, updatedAt
─── Unique: (membershipId, featureKey) ───
```

#### `Invitation`
```
id              String (CUID, PK)
email           String
token           String (unique)
scope           InvitationScope
status          InvitationStatus (default: PENDING)
organizationId  String
role            OrganizationRole
permissions     Json?
invitedById     String
acceptedByUserId String?
expiresAt       DateTime
acceptedAt      DateTime?
createdAt, updatedAt
```

#### `Asset`
```
id             String (CUID, PK)
organizationId String
name           String
type           AssetType
status         AssetStatus  (default: UPLOADING)
mimeType       String
fileSize       Int
s3Key          String (unique)   ← format: {orgId}/assets/{assetId}/{sanitized_name}
width          Int?
height         Int?
durationMs     Int?
uploadedById   String
tags           String[]
createdAt, updatedAt
─── Relations ───
organization   → Organization
uploadedBy     → User ("AssetUploader")
campaignAssets → CampaignAsset[]
─── Indexes: (organizationId, createdAt), (organizationId, type) ───
```

#### `Campaign`
```
id             String (CUID, PK)
organizationId String
name           String
description    String
assetCount     Int     (default: 0, denormalized count)
status         CampaignStatus (default: DRAFT)
screens        Int     (default: 0)
impressions    Int     (default: 0)
color          String  (default: "#4ade80")
createdAt, updatedAt
─── Relations ───
organization   → Organization
playlistLinks  → PlaylistCampaign[]
campaignAssets → CampaignAsset[]
```

#### `CampaignAsset`  (join: Campaign ↔ Asset)
```
id              String (CUID, PK)
campaignId      String
assetId         String
position        Int
durationSeconds Int     (default: 10)
createdAt, updatedAt
─── Unique: (campaignId, assetId) ───
─── Indexes: (campaignId, position) ───
```

#### `Playlist`
```
id             String (CUID, PK)
organizationId String
name           String
status         PlaylistStatus (default: DRAFT)
screens        Int     (default: 0)
color          String  (default: "#4ade80")
lastPlayedAt   DateTime?
createdAt, updatedAt
─── Relations ───
organization  → Organization
items         → PlaylistItem[]
campaignLinks → PlaylistCampaign[]
devices       → Device[]   (devices currently assigned this playlist)
```

#### `PlaylistCampaign`  (join: Playlist ↔ Campaign)
```
id         String (CUID, PK)
playlistId String
campaignId String
position   Int    (default: 0)
createdAt, updatedAt
─── Unique: (playlistId, campaignId) ───
─── Indexes: (playlistId, position) ───
```

#### `PlaylistItem`  (free-form items inside a playlist)
```
id              String (CUID, PK)
playlistId      String
name            String
type            String
durationSeconds Int
position        Int
createdAt, updatedAt
─── Index: (playlistId, position) ───
```

#### `ScheduleEvent`
```
id             String (CUID, PK)
organizationId String
name           String
campaign       String
startTime      String        (e.g., "09:00")
endTime        String        (e.g., "17:00")
days           String[]      (e.g., ["MON","WED","FRI"])
screens        Int           (default: 0)
status         ScheduleStatus (default: SCHEDULED)
color          String        (default: "#4ade80")
priority       SchedulePriority (default: NORMAL)
recurring      Boolean       (default: true)
createdAt, updatedAt
```

#### `Device`
```
id                String (CUID, PK)
organizationId    String?     (null until paired)
name              String
status            DeviceStatus (default: OFFLINE)
location          String      (default: "Pending")
ip                String      (default: "Pending")
resolution        String      (default: "1920x1080")
uptime            String      (default: "0s")
cpu               Int         (0–100 %)
ram               Int         (0–100 %)
temp              Int         (0–120 °C)
lastSync          String
os                String      (default: "Unknown")
currentContent    String?     (currently playing asset name)
currentPlaylistId String?
── Pairing fields ──
pairingCode       String?     (unique, 6-char alphanumeric, cleared after pairing)
deviceToken       String?     (unique, 64-char hex, set when CMS pairs device)
hardwareId        String?     (unique, UUID generated by Android app on first boot)
isPaired          Boolean     (default: false)
createdAt, updatedAt
─── Relations ───
organization    → Organization?
currentPlaylist → Playlist? (onDelete: SetNull)
─── Indexes: (organizationId, createdAt), (organizationId, currentPlaylistId) ───
```

#### `Ticker`
```
id             String (CUID, PK)
organizationId String
text           String
speed          TickerSpeed    (default: NORMAL)
style          TickerStyle    (default: NEON)
color          String         (default: "#00e5ff")
status         TickerStatus   (default: DRAFT)
priority       TickerPriority (default: NORMAL)
screens        Int            (default: 0)
createdAt, updatedAt
```

#### `ProofOfPlayLog`
```
id             String (CUID, PK)
organizationId String
device         String      (device name, denormalized)
content        String      (asset name played)
status         ProofOfPlayStatus
timestamp      DateTime    (when playback started)
createdAt
─── Index: (organizationId, timestamp) ───
```

#### `AuditLog`
```
id             String (CUID, PK)
actorUserId    String?
organizationId String?
action         String    (e.g. "asset.uploaded", "invitation.accepted")
targetType     String    (e.g. "asset", "membership")
targetId       String?
summary        String    (human-readable description)
metadata       Json?
createdAt
─── Indexes: (organizationId, createdAt), (actorUserId, createdAt) ───
```

---

## 7. Authentication & Authorization

### 7.1 User Authentication Flow

```
1. Bootstrap (first run only)
   POST /api/auth/bootstrap/super-admin  → creates first SUPER_ADMIN

2. Login
   POST /api/auth/login  { email, password }
   → verifies bcrypt hash → returns { accessToken, user }
   → JWT signed with JWT_SECRET, expires in 12h, payload: { sub: userId }

3. Every subsequent request
   Frontend attaches: Authorization: Bearer <accessToken>
   Frontend also attaches: x-organization-id: <orgId>  (from localStorage)
   JwtAuthGuard verifies token → resolves RequestActor

4. GET /api/auth/me → returns resolved user + all memberships + active org context

5. Invitations
   Org admin: POST /api/organizations/:orgId/members/invitations
   Invitee: POST /api/auth/accept-invitation { token, fullName, password }
   → creates/updates User + OrganizationMembership → returns JWT session
```

### 7.2 RequestActor Interface

Every JWT-guarded controller receives a `RequestActor` from `@CurrentActor()`:

```typescript
interface RequestActor {
  userId: string;
  email: string;
  fullName: string;
  platformRole: PlatformRole | null;   // null for pure tenant users
  organization?: {
    id: string;
    slug: string;
    role: OrganizationRole;
    status: OrganizationStatus;
  };
}
```

### 7.3 Authorization Rules

- **Platform-level access**: `platformRole` is `SUPER_ADMIN`, `PLATFORM_ADMIN`, `SALES`, or `SUPPORT`.
- **Tenant-scoped access**: Every service calls `ensureOrganizationAccess(actor, organizationId)`:
  - `SUPER_ADMIN` / `PLATFORM_ADMIN` → unconditional access.
  - Otherwise: `actor.organization?.id` must equal `organizationId`.
  - Failure: `ForbiddenException`.
- **Feature-level gates**: Driven by `MembershipFeaturePermission`. Role defaults computed in the web layer if no explicit permission row exists.

### 7.4 Device Authentication (Android Player)

Devices do NOT use JWTs. After pairing:
- Device receives a `deviceToken` (64-char hex random string).
- All player API calls include: `Authorization: Bearer <deviceToken>`.
- Backend resolves device via `Device.deviceToken` field — no JWT involved.

---

## 8. Backend API Reference

**Base URL (dev):** `http://localhost:3001/api`  
**All tenant-user endpoints require:** `Authorization: Bearer <jwt>` + `x-organization-id: <orgId>`  

### 8.1 Auth (`/api/auth`)

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/auth/bootstrap/super-admin` | None | First-run: create the first SUPER_ADMIN. No-op after. |
| `POST` | `/auth/login` | None | `{ email, password }` → `{ accessToken, user }` |
| `POST` | `/auth/accept-invitation` | None | `{ token, fullName, password }` → JWT session |
| `GET` | `/auth/me` | JWT | Returns current `RequestActor` with memberships |

### 8.2 Users (`/api/users`)

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/users` | JWT | List all platform users |
| `POST` | `/users` | JWT | Create a platform user |

### 8.3 Organizations (`/api/organizations`)

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/organizations` | JWT | List all organizations |
| `GET` | `/organizations/:orgId` | JWT | Get single org |
| `POST` | `/organizations` | JWT | Create org |
| `PATCH` | `/organizations/:orgId/activate` | JWT | Activate org (DRAFT → ACTIVE) |
| `POST` | `/organizations/:orgId/first-admin-invitations` | JWT | Seed first org admin |
| `GET` | `/organizations/:orgId/members` | JWT | List members |
| `POST` | `/organizations/:orgId/members` | JWT | Add member directly |
| `POST` | `/organizations/:orgId/members/invitations` | JWT | Send invite email |
| `PATCH` | `/organizations/:orgId/members/:membershipId/role` | JWT | Update member role |
| `PATCH` | `/organizations/:orgId/members/:membershipId/permissions` | JWT | Update feature permissions |
| `DELETE` | `/organizations/:orgId/members/:membershipId` | JWT | Remove member |

### 8.4 Assets (`/api/organizations/:orgId/assets`)

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/assets/upload-url` | JWT | Request presigned S3 PUT URL → `{ asset, uploadUrl }` |
| `PATCH` | `/assets/:assetId/confirm` | JWT | Confirm upload complete (API HEADs S3) → `{ asset, downloadUrl }` |
| `GET` | `/assets` | JWT | List READY assets. Query: `?type=IMAGE&search=foo&page=1` |
| `GET` | `/assets/:assetId` | JWT | Single asset + presigned download URL |
| `DELETE` | `/assets/:assetId` | JWT | Delete from S3 + DB |
| `PATCH` | `/assets/:assetId/tags` | JWT | Update tags array |

### 8.5 Client Data (`/api/client-data`) — Tenant Dashboard

All endpoints require: `Authorization: Bearer <jwt>` + `x-organization-id: <orgId>` header.

#### Dashboard
| Method | Path | Description |
|---|---|---|
| `GET` | `/client-data/dashboard` | Aggregate stats for the org dashboard |

#### Campaigns
| Method | Path | Description |
|---|---|---|
| `GET` | `/client-data/campaigns` | List all campaigns |
| `POST` | `/client-data/campaigns` | Create campaign `{ name, description? }` |
| `DELETE` | `/client-data/campaigns/:campaignId` | Delete campaign |
| `GET` | `/client-data/campaigns/:campaignId/assets` | List campaign's assets |
| `POST` | `/client-data/campaigns/:campaignId/assets` | Add asset `{ assetId, durationSeconds }` |
| `DELETE` | `/client-data/campaigns/:campaignId/assets/:assetId` | Remove asset from campaign |
| `PATCH` | `/client-data/campaigns/:campaignId/assets/reorder` | Reorder `{ assetIds: string[] }` |

#### Playlists
| Method | Path | Description |
|---|---|---|
| `GET` | `/client-data/playlists` | List all playlists |
| `POST` | `/client-data/playlists` | Create `{ name }` |
| `DELETE` | `/client-data/playlists/:playlistId` | Delete playlist |
| `PATCH` | `/client-data/playlists/:playlistId/reorder` | Reorder items `{ itemIds: string[] }` |
| `GET` | `/client-data/playlists/assignment-options` | Campaigns + devices available for assignment |
| `PATCH` | `/client-data/playlists/:playlistId/assign` | Assign `{ campaignIds, deviceIds }` |

#### Schedule Events
| Method | Path | Description |
|---|---|---|
| `GET` | `/client-data/schedule-events` | List all events |
| `POST` | `/client-data/schedule-events` | Create event |
| `PATCH` | `/client-data/schedule-events/:eventId` | Update event |
| `PATCH` | `/client-data/schedule-events/:eventId/toggle` | Toggle ACTIVE ↔ PAUSED |
| `DELETE` | `/client-data/schedule-events/:eventId` | Delete event |

#### Devices
| Method | Path | Description |
|---|---|---|
| `GET` | `/client-data/devices` | List devices for org |
| `POST` | `/client-data/devices` | Create device manually |
| `POST` | `/client-data/devices/pair` | Pair Android device `{ pairingCode, name }` → assigns org, generates `deviceToken` |
| `PATCH` | `/client-data/devices/:deviceId` | Update device metadata |
| `DELETE` | `/client-data/devices/:deviceId` | Delete device |
| `POST` | `/client-data/devices/:deviceId/reboot` | Send reboot command |
| `POST` | `/client-data/devices/:deviceId/screenshot` | Request screenshot |
| `POST` | `/client-data/devices/:deviceId/refresh-status` | Force telemetry refresh |

#### Tickers
| Method | Path | Description |
|---|---|---|
| `GET` | `/client-data/tickers` | List tickers |
| `POST` | `/client-data/tickers` | Create ticker |
| `PATCH` | `/client-data/tickers/:tickerId` | Update ticker |
| `PATCH` | `/client-data/tickers/:tickerId/toggle` | Toggle ACTIVE ↔ PAUSED |
| `DELETE` | `/client-data/tickers/:tickerId` | Delete ticker |

#### Reports
| Method | Path | Description |
|---|---|---|
| `GET` | `/client-data/reports?range=7d` | Proof-of-play report data. Range: `1d`, `7d`, `30d`, `90d` |
| `GET` | `/client-data/reports/export?range=7d` | Download report as CSV file |

### 8.6 Player API (`/api/player`) — Android Devices Only

These endpoints are **NOT** protected by `JwtAuthGuard`. Authentication is via device token in Authorization header.

#### Pairing (Public — No Auth)

| Method | Path | Description |
|---|---|---|
| `POST` | `/player/init-pairing` | `{ hardwareId }` → `{ hardwareId, isPaired, pairingCode }`. Idempotent. |
| `GET` | `/player/pairing-status/:hardwareId` | Poll every 5s → `{ isPaired, deviceToken, organizationId, deviceName }` |

#### Authenticated Device Endpoints (Bearer `<deviceToken>`)

| Method | Path | Description |
|---|---|---|
| `POST` | `/player/heartbeat` | `{ cpu, ram, temp, currentContent? }` → `{ status: "ok" }`. Call every 60s. |
| `GET` | `/player/sync` | Returns `{ playlist, assets[] }` with pre-signed S3 download URLs (24h expiry). |
| `POST` | `/player/pop-logs` | `{ logs: [{ content, status, timestamp }] }` → `{ received }`. Flush every 5 min. |

### 8.7 Misc

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Liveness probe → `{ status: "ok" }` |
| Static | `/uploads/*` | Legacy local-disk assets (Express `useStaticAssets`) |

---

## 9. Data Flow Diagrams

### 9.1 Asset Upload Flow (3-Step S3 Presigned URL)

```
Browser (Next.js)              NestJS API                    AWS S3
        │                          │                             │
        │ 1. POST /assets/upload-url│                             │
        │   { filename, mime, size }│                             │
        │──────────────────────────►│  Create Asset (UPLOADING)   │
        │                          │  Generate s3Key             │
        │                          │  Presign PUT (1h) ──────────►│
        │◄──{ asset, uploadUrl }───│                             │
        │                          │                             │
        │ 2. PUT <uploadUrl>       │                             │
        │   (raw file body)────────┼────────────────────────────►│
        │◄──────── 200 OK ─────────┼─────────────────────────────│
        │                          │                             │
        │ 3. PATCH /assets/:id/confirm                           │
        │──────────────────────────►│  HEAD s3Key ───────────────►│
        │                          │◄─ size, contentType ────────│
        │                          │  status = READY             │
        │                          │  Write AuditLog             │
        │◄── { asset, downloadUrl }│                             │
```

**S3 key format:** `{organizationId}/assets/{assetId}/{sanitized_filename}`  
**Filename sanitization:** Characters not in `[a-zA-Z0-9._-]` are stripped.

### 9.2 Android Device Pairing Flow

```
Android Player                  NestJS API                  CMS Web Dashboard
      │                             │                              │
      │ 1. Generate UUID hardwareId │                              │
      │ 2. POST /player/init-pairing│                              │
      │    { hardwareId } ─────────►│  Create Device (isPaired=false, pairingCode="A3X9PZ") │
      │◄─── { pairingCode }────────│                              │
      │                             │                              │
      │ 3. Display code on screen   │                              │
      │ 4. Poll every 5s:           │                              │
      │    GET /pairing-status/{id}─►│  { isPaired: false }        │
      │                             │                              │
      │                             │   5. User clicks "Add Device"│
      │                             │   POST /client-data/devices/pair │
      │                             │◄────{ pairingCode, name }────│
      │                             │  Set organizationId          │
      │                             │  Generate deviceToken        │
      │                             │  isPaired = true             │
      │                             │  Clear pairingCode           │
      │                             │                              │
      │ 6. GET /pairing-status/{id}─►│  { isPaired: true, deviceToken, organizationId } │
      │◄─── ─────────────────────── │                              │
      │ 7. Store deviceToken in      │                              │
      │    EncryptedSharedPreferences│                              │
      │ 8. Transition to Playback    │                              │
```

### 9.3 Device Playback Cycle

```
Android Player (paired)         NestJS API

Every 5 minutes:
  GET /player/sync ────────────► Fetch playlist + campaigns + assets
                               ◄─ { playlist, assets: [{ downloadUrl, position, durationSeconds }] }
  Download new/changed assets to local storage
  Play in loop: IMAGE (Coil) | VIDEO (ExoPlayer) | HTML (WebView)

Every 60 seconds:
  POST /player/heartbeat ───────► { cpu, ram, temp, currentContent }
                               ◄─ { status: "ok" }
                                  API updates Device record (status: ONLINE/WARNING)

Every 5 minutes:
  POST /player/pop-logs ────────► { logs: [{ content, status, timestamp }] }
                               ◄─ { received: N }
                                  API writes ProofOfPlayLog records

Offline mode:
  Keep looping cached assets. Queue PoP logs in Room DB. Flush on reconnect.
```

### 9.4 Heartbeat Auto-Status Logic

The API auto-sets `Device.status` on every heartbeat:
- `cpu > 85` OR `temp > 80` → `WARNING`
- Otherwise → `ONLINE`

---

## 10. Frontend Structure (`apps/web/src/`)

```
src/
├── app/                          ← Next.js App Router
│   ├── layout.tsx                ← Root layout (global CSS, fonts)
│   ├── page.tsx                  ← Root redirect logic
│   ├── login/                    ← Login page
│   ├── accept-invitation/        ← Invitation acceptance page
│   ├── display/                  ← Public display/kiosk mode
│   ├── app/                      ← TENANT PORTAL (/app/*)
│   │   ├── layout.tsx            ← Tenant layout (sidebar navigation)
│   │   ├── page.tsx              ← Tenant root (redirect to dashboard)
│   │   ├── dashboard/            ← Org dashboard + stats
│   │   ├── assets/               ← Asset library + upload
│   │   ├── campaigns/            ← Campaign management
│   │   ├── playlists/            ← Playlist builder
│   │   ├── schedule/             ← Schedule calendar/events
│   │   ├── tickers/              ← Ticker management
│   │   ├── devices/              ← Device monitoring + pairing
│   │   ├── designer/             ← Content designer (canvas?)
│   │   ├── control/              ← Device control panel
│   │   ├── reports/              ← Proof-of-play analytics
│   │   └── settings/             ← Org settings
│   └── platform/                 ← PLATFORM PORTAL (/platform/*)
│       ├── layout.tsx            ← Platform layout (sidebar)
│       ├── page.tsx              ← Platform dashboard (org stats, health)
│       ├── organizations/        ← Tenant org management
│       ├── team/                 ← Platform team management
│       ├── billing/              ← Billing (placeholder)
│       ├── reminders/            ← Reminders
│       ├── support/              ← Support tools
│       ├── reports/              ← Platform-level reports
│       └── settings/             ← Platform settings
├── components/                   ← Shared React components
└── lib/
    ├── api.ts                    ← Typed fetch wrapper (apiRequest, apiPost, apiDelete, apiUpload)
    ├── auth-storage.ts           ← localStorage key constants (AUTH_TOKEN_STORAGE_KEY, ACTIVE_ORGANIZATION_STORAGE_KEY)
    ├── navigation/               ← Navigation helpers
    └── permissions/              ← Permission checking helpers
```

### Frontend Auth Flow

1. User logs in → JWT stored in `localStorage` under `AUTH_TOKEN_STORAGE_KEY`.
2. Active org stored in `localStorage` under `ACTIVE_ORGANIZATION_STORAGE_KEY`.
3. Every API call via `apiRequest()` auto-injects `Authorization: Bearer <token>` and `x-organization-id: <orgId>`.
4. On load, `GET /api/auth/me` resolves user context.
5. Platform users → `/platform`. Tenant users → `/app`.

---

## 11. Backend Module Structure (`apps/api/src/`)

```
src/
├── main.ts                   ← Bootstrap: ValidationPipe, CORS, /api prefix, static /uploads
├── app.module.ts             ← Wires all feature modules
├── health.controller.ts      ← GET /api/health
├── prisma/
│   └── prisma.service.ts     ← Singleton PrismaClient (imported by all modules)
├── s3/
│   └── s3.service.ts         ← S3 wrapper: presignUpload, presignDownload (generateDownloadUrl), headObject, deleteObject
├── audit/
│   └── audit.service.ts      ← AuditService.log({ actorUserId, organizationId, action, targetType, targetId, summary, metadata? })
├── auth/
│   ├── auth.controller.ts    ← /auth/* endpoints
│   ├── auth.service.ts       ← login, bootstrap, acceptInvitation, me, resolveActorFromToken
│   ├── jwt-auth.guard.ts     ← JwtAuthGuard: verifies Bearer JWT, populates RequestActor
│   ├── organization-roles.guard.ts
│   └── platform-roles.guard.ts
├── users/
│   ├── users.controller.ts   ← /users/* endpoints
│   └── users.service.ts
├── organizations/
│   ├── organizations.controller.ts ← /organizations/* endpoints
│   └── organizations.service.ts
├── assets/
│   ├── assets.controller.ts  ← /organizations/:orgId/assets/* endpoints
│   └── assets.service.ts     ← requestUpload, confirmUpload, listAssets, getAsset, deleteAsset, updateTags
├── client-data/
│   ├── client-data.controller.ts ← /client-data/* endpoints (tenant dashboard)
│   └── client-data.service.ts    ← All tenant feature logic (campaigns, playlists, devices, tickers, schedule, reports)
└── player/
    ├── player.controller.ts  ← /player/* endpoints (Android devices)
    └── player.service.ts     ← initPairing, getPairingStatus, heartbeat, syncPlaylist, submitPopLogs
```

### Key Patterns

- **Every tenant-scoped service** begins with `ensureOrganizationAccess(actor, organizationId)`.
- **`@CurrentActor()`** decorator extracts `RequestActor` from the request (set by `JwtAuthGuard`).
- **`JwtAuthGuard`** reads `x-organization-id` header to resolve org context on `RequestActor`.
- **Player endpoints** resolve device via `Authorization: Bearer <deviceToken>` in `resolveDeviceByToken()`.

---

## 12. Shared Packages (`packages/`)

| Package | Purpose |
|---|---|
| `@orion/types` | Shared TypeScript interfaces and type definitions (SDK contract between web and API) |
| `@orion/sdk` | Client SDK helpers (wrappers around API calls) |
| `@orion/ui` | Shared UI primitives (design system components) |
| `@orion/config` | Shared ESLint config, TypeScript base config |

---

## 13. Worker (`apps/worker`)

**Status: Scaffold only — not yet wired.**

Intended future use with BullMQ:
- Video thumbnailing (ffprobe to set `durationMs` on assets)
- Proof-of-play aggregation
- Scheduled-event fan-out to devices
- Email notifications

Will consume the same `DATABASE_URL` and `S3_*` env vars when implemented.

---

## 14. Deployment

| Component | Notes |
|---|---|
| **API** | Single Node process, stateless. Env: `DATABASE_URL`, `JWT_SECRET`, `S3_*`. Run `prisma migrate deploy` on boot. |
| **Web** | `next build` + `next start` or Vercel. Needs `NEXT_PUBLIC_API_URL`. |
| **Database** | Any managed PostgreSQL. |
| **Storage** | Any S3-compatible bucket. Set CORS to production web origin(s). |
| **Netlify** | `netlify.toml` exists at root, suggesting web may be deployed to Netlify. |

### S3 IAM Policy Required

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:HeadObject"],
    "Resource": "arn:aws:s3:::YOUR_BUCKET/*"
  }]
}
```

### S3 Bucket CORS (Required for browser direct uploads)

```json
[{
  "AllowedHeaders": ["*"],
  "AllowedMethods": ["PUT", "GET", "HEAD"],
  "AllowedOrigins": ["http://127.0.0.1:3000", "http://localhost:3000"],
  "ExposeHeaders": ["ETag"],
  "MaxAgeSeconds": 3000
}]
```

---

## 15. Key Conventions & Gotchas

| Rule | Detail |
|---|---|
| **S3 key format** | `{organizationId}/assets/{assetId}/{sanitized_filename}` — sanitized to `[a-zA-Z0-9._-]` |
| **Path-style S3** | Use path-style in dev to bypass DNS issues. `S3_ENDPOINT=https://s3.{region}.amazonaws.com` + `S3_FORCE_PATH_STYLE=true` |
| **JWT expiry** | 12 hours. The web app must handle 401s by redirecting to `/login`. |
| **Prisma schema changes** | `npm run db:migrate` (creates migration file) for dev; `prisma db push` for quick prototyping only. |
| **NestJS watcher** | Reloads on `.ts` file changes but NOT `.env` changes. Restart API after editing `.env`. |
| **Multi-tenant cascade** | ALL tenant-scoped tables have `onDelete: Cascade` from Organization. Deleting an org wipes all its data. |
| **Pairing code format** | 6-char alphanumeric, ambiguous chars excluded: `0,O,1,I`. Unique constraint in DB. |
| **Device token format** | 64-char hex string (`randomBytes(32).toString('hex')`). |
| **Device status auto-logic** | `cpu > 85 OR temp > 80` → WARNING. Otherwise → ONLINE. Triggered by each heartbeat. |
| **Asset status lifecycle** | `UPLOADING` (after `upload-url`) → `READY` (after `confirm`) or `ERROR` (if S3 HEAD fails). |
| **Real credentials** | NEVER commit real AWS keys, JWT secrets, or DB passwords. |

---

## 16. Quick Reference — Where to Find Things

| Question | Location |
|---|---|
| DB schema | `prisma/schema.prisma` |
| Seed data | `prisma/seed.ts` |
| API bootstrap | `apps/api/src/main.ts` |
| Auth logic | `apps/api/src/auth/auth.service.ts` |
| Upload flow (backend) | `apps/api/src/assets/assets.service.ts` |
| S3 wrapper | `apps/api/src/s3/s3.service.ts` |
| Android player API | `apps/api/src/player/player.service.ts` |
| Tenant dashboard API | `apps/api/src/client-data/client-data.service.ts` |
| Frontend API helper | `apps/web/src/lib/api.ts` |
| Tenant portal pages | `apps/web/src/app/app/` |
| Platform portal pages | `apps/web/src/app/platform/` |
| Environment vars | `apps/api/.env.example` + Section 4 of this file |
| Demo credentials | Section 5 of this file |
| Android player guide | `ANDROID_PLAYER_PROMPT.md` |
| Full developer guide | `PROJECT_GUIDE.md` |

---

## 17. Android Player Summary

The Android player is a **separate Kotlin app** (not in this repo). It connects to this backend via the `/api/player/*` endpoints.

### Tech Stack
- Kotlin, Jetpack Compose, ExoPlayer (video), Coil/Glide (images), WebView (HTML)
- Retrofit + OkHttp for networking
- Hilt for DI, Room for local offline PoP log queue
- EncryptedSharedPreferences for secure token storage

### Behavior Summary
1. **First boot** → generate UUID `hardwareId`, call `POST /player/init-pairing` → get pairing code → display on screen.
2. **Poll** `GET /player/pairing-status/:hardwareId` every 5 seconds until `isPaired=true`.
3. **Store** `deviceToken` + `organizationId` in EncryptedSharedPreferences.
4. **Playback** → `GET /player/sync` every 5 minutes → download assets to local cache → play in loop.
5. **Heartbeat** → `POST /player/heartbeat` every 60 seconds (cpu, ram, temp, currentContent).
6. **PoP logs** → queue in Room DB → flush via `POST /player/pop-logs` every 5 minutes.
7. **Offline mode** → keep looping cached assets, queue logs, flush on reconnect.
8. **Kiosk mode** → `startLockTask()`, `FLAG_KEEP_SCREEN_ON`, `RECEIVE_BOOT_COMPLETED`, immersive full-screen.

---

*Last updated: 2026-05-27. If you add a new module, API endpoint, or change the data model, update this file.*
