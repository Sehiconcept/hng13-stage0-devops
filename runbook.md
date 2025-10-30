# 🚨 DevOps Alerting Runbook 🚨

This runbook explains what our automated Slack alerts mean and what to do when you receive one.

---

### 🚨 FAILOVER DETECTED 🚨

* **What it means:** The primary pool (usually **BLUE**) is failing. Nginx has automatically shifted all traffic to the backup pool (**GREEN**). The site is still up, but we are running *without* a backup.
* **Operator Action:**
    1.  **Investigate:** Check the logs of the *failed* primary container: `docker-compose logs app_blue`.
    2.  **Identify Cause:** Look for crash loops or database connection errors.
    3.  **Resolve:** A simple restart may fix it: `docker-compose restart app_blue`.

---

### ✅ RECOVERY ✅

* **What it means:** The primary pool (**BLUE**) has recovered. Nginx has automatically shifted traffic back to it.
* **Operator Action:**
    1.  **Monitor:** No immediate action is required. This is a "good" alert.

---

### 📈 HIGH ERROR RATE 📈

* **What it means:** More than `X%` of recent requests to the *currently active* pool are returning 5xx server errors. Users are being affected.
* **Operator Action:**
    1.  **Identify Pool:** The alert message will state which pool is active.
    2.  **Check Logs:** Check the logs for that active container: `docker-compose logs <active_pool_name>`.
    3.  **Manual Failover:** If the primary is erroring, you can force a manual failover:
        1.  Edit `.env` and set `ACTIVE_POOL=green`.
        2.  Relaunch Nginx: `docker-compose up -d nginx_lb`.

---

### 🔧 Maintenance Mode 🔧

* **What it is:** A way to *temporarily suppress all alerts* during planned maintenance.
* **How to Use:**
    1.  In `.env`, set `MAINTENANCE_MODE=true`.
    2.  Relaunch the watcher: `docker-compose up -d alert_watcher`.
    3.  Do your work.
    4.  Set `MAINTENANCE_MODE=false` and relaunch the watcher to turn alerts back on.
