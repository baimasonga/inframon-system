# InfraMon: Advanced Construction Field Monitoring System

InfraMon is a production-grade field engineering suite designed for infrastructure projects in Sierra Leone. It enables real-time progress tracking, regional governance, and AI-driven quality auditing.

## 🏗 System Architecture

The ecosystem consists of three interconnected layers:

### 1. The Mobile Field Tool (Flutter)
- **Role**: Data Feeder for inspectors.
- **Key Features**: Offline-first reporting, multi-step inspection wizards, and automated background sync.
- **Scoping**: Inspectors only see projects in their assigned districts (Moyamba, Bo, etc.) based on their **Operational Profile**.

### 2. The Command Dashboard (Next.js)
- **Role**: Executive Monitoring & Administration.
- **Key Features**: Real-time project analytics, automated AI photo auditing, and secure user management.
- **Admin Actions**: Allows project engineers to register inspectors and defined professional purviews (Roads, Buildings, etc.).

### 3. The Governance Backend (Supabase/Postgres)
- **Role**: Source of Truth & Security.
- **Key Features**: Row Level Security (RLS) policies that enforce regional scoping, and stored procedures for high-performance sync.

---

## 🛠 Strategic Workflows

### 🛡 Regional Governance
Project data is restricted by **Territory (District/Chiefdom)** and **Specialization**. An inspector specializing in "Boreholes" in "Bo District" will not see unconnected road statistics.

### 🤖 AI-Driven Quality Auditing
As site photos are synced, they are queued for **AI Vision Analysis**. This system automatically flags defects, missing safety gear, and estimates completion percentages, providing managers with a "second set of eyes" on every site.

### 📡 Connection-Aware Sync
Optimized for mobile bandwidth. Reports are queued locally and pushed only when a stable connection is found, ensuring data continuity in remote rural locations.

---

## 📋 Directory Structure

- `/mobile_app`: Flutter (Dart) source code for Android/iOS.
- `/web_dashboard`: Next.js (TypeScript) dashboard source.
- `/backend`: SQL migration and schema scripts for Supabase.

---
**Developed by Antigravity for SECAP Training.**
