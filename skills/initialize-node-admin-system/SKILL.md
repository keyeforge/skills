---
name: initialize-node-admin-system
description: Initialize a new Node.js admin system from the keyeforge/directus-template GitHub template. Use when the user asks to create, scaffold, clone, bootstrap, or initialize a Node.js backend/admin system, Directus CRM/admin project, React admin console, or a new project based on https://github.com/keyeforge/directus-template.
---

# Initialize Node Admin System

Use this skill to initialize a new project from the Directus + React admin template:

`https://github.com/keyeforge/directus-template`

The template contains a Directus 11 backend, SQLite database bootstrap scripts, a Directus hook extension, and a React/Vite/Ant Design admin frontend.

## Required Inputs

Before making changes, determine:

1. Target project name, for example `acme-crm`.
2. Target parent directory, for example `/Users/abc/wp`.
3. Whether to start a fresh Git repository after cloning.
4. Initial Directus admin email and password, unless the user wants placeholders.

If the user gives only a display name, derive a filesystem-safe slug:

- Lowercase the name.
- Convert spaces, underscores, and punctuation to `-`.
- Remove characters outside `a-z`, `0-9`, and `-`.
- Collapse repeated `-`.
- Trim leading/trailing `-`.
- If the result is empty, ask for a valid project name.

Use the slug for the directory name and npm package name. Preserve the user's original display name only in user-facing documentation if needed.

## Initialization Workflow

1. Verify the parent directory exists and the target directory does not already contain unrelated work.
2. Clone the template:

```bash
git clone https://github.com/keyeforge/directus-template.git <project-slug>
```

3. Enter the new project directory.
4. Remove template Git history unless the user explicitly wants to keep it:

```bash
rm -rf .git
```

5. Create environment files from examples when missing:

```bash
cp .env.example .env
cp frontend/.env.example frontend/.env
```

6. Generate a strong Directus `SECRET`:

```bash
openssl rand -hex 32
```

7. Update `.env`:

```dotenv
SECRET=<generated-64-char-hex-secret>
ADMIN_EMAIL=<admin-email>
ADMIN_PASSWORD=<admin-password>
```

8. Update `frontend/package.json`:

```json
{
  "name": "<project-slug>-frontend"
}
```

9. Leave `extensions/data-scope-filter/package.json` unchanged unless the user asks to rename the Directus extension.
10. Install frontend dependencies:

```bash
cd frontend && npm install
```

11. If the user wants a fresh Git repository:

```bash
git init
git add .
git commit -m "Initial project from Directus admin template"
```

Only commit when the user explicitly asked for a commit.

## Optional Bootstrap

When the user wants the project fully runnable, start Directus and initialize the schema:

```bash
docker compose up -d
sqlite3 database/data.db < scripts/bootstrap-customers.sql
sqlite3 database/data.db < scripts/bootstrap-contacts.sql
sqlite3 database/data.db < scripts/bootstrap-opportunities.sql
sqlite3 database/data.db < scripts/bootstrap-quotes.sql
sqlite3 database/data.db < scripts/bootstrap-departments.sql
sqlite3 database/data.db < scripts/bootstrap-user-org-fields.sql
sqlite3 database/data.db < scripts/bootstrap-org-closure.sql
sqlite3 database/data.db < scripts/bootstrap-owner-id.sql
sqlite3 database/data.db < scripts/bootstrap-policy-data-scopes.sql
docker compose restart directus
```

Then run the frontend:

```bash
cd frontend && npm run dev
```

Default URLs:

- Directus: `http://localhost:8055`
- Frontend: `http://localhost:5173`

## Validation

After initialization, verify:

- `.env` exists and does not contain the placeholder `replace-with-random-64-char-hex-string`.
- `frontend/package.json` has the derived project-specific package name.
- `frontend/.env` points to the intended Directus URL.
- `npm run build` passes in `frontend/` when the user asks for a build check.
- `docker compose ps` shows Directus running when the user asks for a runnable local setup.

Do not commit `.env`, `database/data.db`, uploads, or other local runtime state unless the user explicitly asks and understands the risk.
