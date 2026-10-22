# DFM Finance Portfolio

A Visual Studio 2012-compatible ASP.NET Web API 2 and AngularJS 1.x application for project registration, PET review/approval, CAPEX/OPEX control, budget lines, invoices, attachments, and management reporting.

## Solution

- `DFM.Web`: .NET Framework 4.5 Web API and AngularJS single-page UI.
- `DFM.DirectorySync`: scheduled Active Directory user/email synchronization.
- `DFM.OfflineSync`: scheduled CAPEX, OPEX, and exported JIRA CSV synchronization.
- `Database`: SQL Server 2012-compatible schema and incremental migrations.
- `Js`: source screenshots, JIRA customizations, CSV examples, and the original JIRA fetch utility.

## Setup

1. Open `DFM.sln` in Visual Studio 2012 with .NET Framework 4.5 and ASP.NET Web Tools installed.
2. Enable NuGet package restore. The solution pins Web API `5.2.9` and Newtonsoft.Json `13.0.3`, both targeting .NET 4.5.
3. Run `Database/001_DFM_Schema.sql`, then each higher-numbered migration against SQL Server, including `Database/045_Non_Project_OPEX.sql`.
4. Update the `DFM` connection string in `DFM.Web/Web.config`.
5. Update LDAP settings and the connection string in `DFM.DirectorySync/App.config`.
6. Verify source paths and the connection string in `DFM.OfflineSync/App.config`.
7. Publish `DFM.Web` to IIS using an application pool configured for .NET CLR v4.0 and Integrated pipeline mode.

For UI-only review, open `http://localhost:8090` while the local preview server is running. The UI uses preview data when the API is unavailable.

## Authentication

AD synchronization creates or updates users by email and assigns `Requestor` by default. The first-time password endpoint is anonymous only while `RequiresPasswordSetup=1`. Passwords and security answers use PBKDF2 with independent random salts. Reset challenges issue single-use tokens that expire after 15 minutes. API sessions expire after eight hours and are stored as SHA-256 token hashes.

Roles:

- `Requestor`: register JIRA/non-JIRA projects, submit/edit PET and spend, attach files, and maintain approved budget lines/invoices.
- `Reviewer`: Accountable Executive Lead; accepts or rejects `Pending Review` PETs.
- `Approver`: Accountable Executive; accepts or rejects `Pending Approval` PETs.
- `Master`: Requestor capabilities plus CAPEX/OPEX edit and offline source administration.

Assign Reviewer, Approver, and Master roles through `dbo.UserRoles`; do not infer privileged roles from an AD display name.

## Offline jobs

Run both consoles using Windows Task Scheduler under service accounts with least-privilege database permissions:

```powershell
DFM.DirectorySync.exe
DFM.OfflineSync.exe
```

A practical schedule is nightly for AD and financial files, and after each approved JIRA export for JIRA. `DFM.OfflineSync` correctly handles quoted CSV values and Indian-style grouped amounts. The original API-based JIRA collector remains in `Js/Program.cs` for networks where a scheduled host can reach JIRA; the web application never calls JIRA in real time.

## API

Anonymous authentication routes:

- `POST /api/auth/login`
- `GET /api/auth/security-questions`
- `POST /api/auth/first-time-setup`
- `POST /api/auth/reset/challenge`
- `POST /api/auth/reset/complete`

Bearer-protected portfolio routes:

- `GET /api/portfolio/dashboard`
- `GET /api/portfolio/projects/{id}`
- `POST /api/portfolio/projects`, `/pets`, `/spend-items`, `/budget-lines`, `/invoices`
- `POST /api/portfolio/pets/{id}/review` and `/approve`
- `PUT /api/portfolio/budgets/{id}` (`Master` only)
- `POST /api/portfolio/attachments/{entityType}/{entityId}`
- `POST /api/portfolio/bulk/{pet|budget|invoice}/{parentId}` with raw `text/csv`
- `POST /api/portfolio/non-project-opex/import` with a Non-Project OPEX CSV/Excel file and required supporting document

CSV templates are under `DFM.Web/templates` and are downloadable from the main page. Non-Project OPEX imports require every screenshot column, `Initiative`, `Line Item`, `Budget Type`, `Amount Apprd(AED)`, and `Vendor`; the budget type must be OPEX.

## Workflow invariant

Final PET approval locks the budget source row in a SQL transaction, rejects requests above the remaining balance, then updates utilization and available balance exactly once. Budget lines cannot be created until the PET is approved. Spend lines cannot be changed after reviewer approval. Workflow decisions and Master budget changes are audited.

## Production checklist

- Replace all `CHANGE_ME` values and keep credentials out of source control.
- Grant the web SQL login execute rights only on application procedures plus required view/table reads.
- Restrict attachment extensions and add enterprise malware scanning before production use.
- Host AngularJS and Lucide files locally if the IIS network cannot access the public CDNs.
- Configure HTTPS, secure headers, IIS request limits, backup/retention, and SQL auditing.
- Disable UI preview data in `app/app.js` after the authenticated production shell is connected.
