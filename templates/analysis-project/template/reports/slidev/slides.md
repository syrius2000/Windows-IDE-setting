---
theme: default
background: https://cover.sli.dev
title: RWD Analysis Overview
info: |
  ## Osaka University RWD Analysis Platform
  Statistical Case Study Presentation
class: text-center
drawings:
  persist: false
transition: slide-left
mdc: true
---

# RWD Analysis Case Study
## Osaka University Biostatistics & RWD Platform

<div class="pt-12">
  <span class="px-2 py-1 rounded bg-teal-500 text-white font-mono">Statistical Expert Team</span>
</div>

---

# Architecture & 4 Golden Rules

- 📂 **src/**: All source code (SAS CP932, Python, R, TypeScript)
- 📊 **sql/**: Database extract queries and data dictionary schemas
- 📑 **reports/**: Quarto, Slidev, and PowerPoint templates
- 📦 **outputs/**: Strictly separated into `private/` (untracked) and `release/` (audited)

---

# Data Security & Boundaries

| Classification | Storage | Cloud AI |
| :--- | :--- | :--- |
| Synthetic | `data/synthetic/` | ✅ Allowed |
| De-identified | MySQL LAN | 🔒 Local Only |
| Sensitive Raw | External Protected | 🚫 Offline Only |
