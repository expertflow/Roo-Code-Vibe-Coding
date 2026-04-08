# 🌍 Expertflow Global Corporate Governance

## 1. Economic Engineering Mandate
All architectural decisions and software evaluations within the Expertflow ecosystem must prioritize long-term operational leanest and decoupling from variable licensing costs.

### 1.1 The Licensing Lever Rule
Every software tool proposed or evaluated in this monorepo must include a **Licensing Lever Analysis**. This analysis must identify the exact commercial triggers for that software.
- **Mandatory Reporting**: Evaluation must ignore generic metrics (e.g., company size) and focus on the software's specific levers (Builder seats, Revenue thresholds, API volumes, Storage tiers).
- **Justification**: Tools will only be approved if they demonstrate a clear ROI compared to existing "per-user" SaaS licenses.

## 2. Architectural Sovereignty
Expertflow prioritizes solutions that guarantee full ownership of data schemas and source code. 
- **Vendor Lock-in Control**: Preference is given to open-source or portable frameworks (e.g., self-hosted PostgreSQL over proprietary NoSQL).
- **AI-Native Compatibility**: Tools must be evaluated for "Vibecoding" compatibility—meaning they provide clean, text-based APIs or schemas that AI agents can natively understand.

## 3. Security Governance
- **Zero-Trust Logic**: Security (RBAC/RLS) must be managed at the API/Backend layer, never solely in the Frontend.
- **Safety Layer**: Direct database access should be restricted via managed proxies (like Directus) to ensure AI-assisted development ("vibecoding") cannot accidentally bypass security protocols.
