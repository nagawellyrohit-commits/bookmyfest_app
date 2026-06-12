# CollegeConnect Backend Server Setup Guide

This backend is built using **Node.js (Express)** and **PostgreSQL** (managed through **Prisma ORM**). Follow these instructions to set it up locally on this machine or any other laptop.

---

## Prerequisites

Make sure you have the following installed on your machine:
1. **Node.js** (v16.x or higher, v18+ recommended): [Download Node.js](https://nodejs.org/)
2. **PostgreSQL** (v14 or higher): Follow the installation steps below.

---

## 1. PostgreSQL Installation & Configuration

### Option A: Standard Installation (Recommended for Windows/macOS)

1. **Download the Installer**:
   * Go to the official [EnterpriseDB PostgreSQL Downloads](https://www.enterprisedb.com/downloads/postgres-postgresql-downloads).
   * Choose the version matching your OS (e.g., v15 or v16 for Windows x86-64).

2. **Run the Installer**:
   * Double-click the installer and follow the instructions.
   * **Password**: During installation, it will ask you to set a password for the default `postgres` user. **Set it to `postgres`** to match the project's default configuration.
   * **Port**: Leave the default port as `5432`.
   * **pgAdmin**: Keep pgAdmin checked (this is a GUI tool that lets you manage your databases easily).

3. **Create the Database**:
   * Open **pgAdmin** from your start menu/applications folder.
   * Connect to the server using the master password you created (`postgres`).
   * Right-click on **Databases** $\rightarrow$ **Create** $\rightarrow$ **Database...**
   * Name the database: `collegeconnect`
   * Click **Save**.

---

### Option B: Docker Installation (For advanced users)

If you prefer using Docker to run PostgreSQL without installing it on your system directly, open your terminal and run:

```bash
docker run --name collegeconnect-postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=collegeconnect -p 5432:5432 -d postgres:latest
```

---

## 2. Project Configuration

1. Open your terminal in the `server` directory:
   ```bash
   cd d:/trying_flutter/student_app/server
   ```

2. Install the Node.js dependencies:
   ```bash
   npm install
   ```

3. Create a `.env` file in the root of the `server/` directory:
   ```env
   PORT=5000
   DATABASE_URL="postgresql://postgres:postgres@localhost:5432/collegeconnect?schema=public"
   JWT_SECRET="YOUR_SUPER_SECRET_JWT_KEY_CHANGE_THIS_IN_PRODUCTION"
   
   # SMTP Configuration (Emails)
   SMTP_HOST="smtp.mailtrap.io"
   SMTP_PORT=2525
   SMTP_USER="YOUR_SMTP_USER"
   SMTP_PASS="YOUR_SMTP_PASS"
   SMTP_FROM="no-reply@collegeconnect.com"
   
   # WhatsApp Provider Configuration (Example: Twilio or BSP API)
   WHATSAPP_API_URL="https://api.twilio.com/2010-04-01/Accounts/YOUR_ACCOUNT_SID/Messages.json"
   WHATSAPP_AUTH_TOKEN="YOUR_WHATSAPP_AUTH_TOKEN"
   WHATSAPP_FROM_NUMBER="whatsapp:+14155238886"
   ```

---

## 3. Database Migrations (Prisma)

Once PostgreSQL is running and you have created the `collegeconnect` database:

1. Generate the Prisma Client and deploy the database schema tables:
   ```bash
   npx prisma migrate dev --name init
   ```
   *This command reads the schema in `prisma/schema.prisma` and automatically creates all the tables, relations, and columns in your local database.*

2. To view and manage database records visually via a web interface, run:
   ```bash
   npm run db:studio
   ```
   *This launches Prisma Studio on [http://localhost:5555](http://localhost:5555).*

---

## 4. Run the API Server

Start the Node.js server in development mode (with hot-reloading enabled):
```bash
npm run dev
```
The server will start listening on port `5000` (e.g., `http://localhost:5000/api`).

---

## API Base Endpoints Created
* **User Authentication**:
  * `POST /api/auth/register` - Register a student, coordinator, or admin
  * `POST /api/auth/login` - Authenticate credentials and return JWT
  * `GET /api/auth/me` - Retrieve current user profile (requires Bearer JWT)
