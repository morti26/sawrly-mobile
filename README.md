# Sawrly Web

Next.js + PostgreSQL backend for Sawrly.

The repository layout mirrors the production server:

```text
public/ on the server == this repository root
mobile/              == Flutter mobile app
```

## Local development

Run the Next.js app locally:

```powershell
npm install
npm run dev -- -H 127.0.0.1 -p 3001
```

Open:

```text
http://127.0.0.1:3001
```

Work on the Flutter app from:

```powershell
cd mobile
flutter pub get
flutter run
```

Before deployment:

```powershell
npm run test
npm run build
```

## Production sync

Production path:

```text
/mnt/disk-extra/hostingdata/cmnp2kdic001a4hr2yofnyk76/sawrly.com/public
```

Download a safe server snapshot into a new local folder:

```powershell
.\scripts\sync_from_server.ps1 -User serveruser
```

Deploy this local repository to production:

```powershell
.\scripts\deploy_sawrly.ps1 -User serveruser
```

Optional SSH flags:

```powershell
.\scripts\deploy_sawrly.ps1 -User morti
.\scripts\deploy_sawrly.ps1 -User morti -Server 192.168.50.150 -Port 22 -IdentityFile C:\Users\mon24\.ssh\id_ed25519
```

The deploy script creates a `/tmp/sawrly-public-backup-*.tar.gz` backup on the server before extracting the new files.

## GitHub backup

After local changes are tested:

```powershell
git status
git add .
git commit -m "Update Sawrly web and mobile"
git push origin main
```

## Deployment on Ubuntu

Follow these steps to deploy the backend on a fresh Ubuntu server.

### 1. Prerequisites
Install Node.js (v18+), PostgreSQL, and Nginx.
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Install Nginx & PM2
sudo apt install -y nginx
sudo npm install -g pm2
```

### 2. Database Setup
Create the database and user.
```bash
sudo -u postgres psql
```
Inside SQL shell:
```sql
-- Create User
CREATE USER fotgraf_user WITH PASSWORD 'secure_password_here';

-- Create DB
CREATE DATABASE fotgraf_db OWNER fotgraf_user;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE fotgraf_db TO fotgraf_user;
\q
```
**Important**: Replace `secure_password_here` with a strong password.

### 3. Application Setup
Clone the repo and configure environment.

```bash
# Clone (replace with your repo)
git clone https://github.com/your-repo/fotgraf.git
cd fotgraf/web

# Install dependencies
npm install

# Configure Environment
cp .env.example .env
nano .env
```
**In `.env`, set:**
- `DATABASE_URL="postgresql://fotgraf_user:secure_password_here@localhost:5432/fotgraf_db?schema=public"`
- `ADMIN_WHATSAPP_E164="964..."` 
- `JWT_SECRET` (generate a long random string)
- `APP_SETTINGS_ENCRYPTION_KEY` (long random string used to encrypt admin payment API keys)

### 4. Schema Migration
Initialize the database schema.
```bash
# Run schema.sql using psql
export DATABASE_URL="postgresql://fotgraf_user:secure_password_here@localhost:5432/fotgraf_db?schema=public"
psql $DATABASE_URL -f schema.sql
```

### 5. Build & Run
Build the Next.js app and start it with PM2.
```bash
npm run build
pm2 start npm --name "fotgraf-web" -- start
pm2 save
pm2 startup
```

### 6. Nginx Reverse Proxy
Configure Nginx to forward port 80 to 3000.
```bash
sudo nano /etc/nginx/sites-available/default
```
Add:
```nginx
server {
    listen 80;
    server_name your_domain_or_ip;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```
Restart Nginx:
```bash
sudo systemctl restart nginx
```
