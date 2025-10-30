import os
import json
import time
import requests
import tailer
from collections import deque

# --- 1. Load Configuration from Environment Variables ---
SLACK_WEBHOOK_URL = os.environ.get("SLACK_WEBHOOK_URL")
INITIAL_POOL = os.environ.get("ACTIVE_POOL", "blue")
WINDOW_SIZE = int(os.environ.get("WINDOW_SIZE", 200))
ERROR_RATE_THRESHOLD = float(os.environ.get("ERROR_RATE_THRESHOLD", 2.0))
ALERT_COOLDOWN_SEC = int(os.environ.get("ALERT_COOLDOWN_SEC", 300))
MAINTENANCE_MODE = os.environ.get("MAINTENANCE_MODE", "false").lower() == "true"
LOG_FILE = "/var/log/nginx/access.log"

# --- 2. Global State Variables ---
last_pool = "unknown"
recent_requests = deque(maxlen=WINDOW_SIZE)
last_alert_time = {}

# --- 3. Slack Alerter Function ---
def send_slack_alert(title, message, alert_type):
    global last_alert_time
    if MAINTENANCE_MODE:
        print(f"MAINTENANCE MODE: Skipping alert: {title}")
        return

    last_sent = last_alert_time.get(alert_type, 0)
    if (time.time() - last_sent) < ALERT_COOLDOWN_SEC:
        print(f"COOLDOWN: Skipping alert: {title}")
        return

    print(f"SENDING SLACK ALERT: {title}")
    if not SLACK_WEBHOOK_URL:
        print("ERROR: SLACK_WEBHOOK_URL is not set. Cannot send alert.")
        return

    payload = {"text": f"{title}\n{message}"}
    try:
        requests.post(SLACK_WEBHOOK_URL, json=payload, timeout=5)
        last_alert_time[alert_type] = time.time()
    except requests.RequestException as e:
        print(f"Error sending Slack alert: {e}")

# --- 4. Main Log Processing Loop ---
def process_log_line(line):
    global last_pool, recent_requests
    try:
        log = json.loads(line)
    except json.JSONDecodeError:
        return

    pool = log.get("pool")
    status = log.get("upstream_status")

    if not pool or not status:
        return # Not an app request, skip it

    # --- Failover & Recovery Detection ---
    if last_pool == "unknown":
        print(f"Initial pool detected: {pool}. Monitoring for changes.")
        last_pool = pool

    if pool != last_pool:
        if pool == "green":
            title = "🚨 FAILOVER DETECTED 🚨"
            message = f"Primary pool **{last_pool.upper()}** appears down. Failing over to backup pool **{pool.upper()}**."
            send_slack_alert(title, message, alert_type="failover")
        elif pool == "blue":
            title = "✅ RECOVERY ✅"
            message = f"Primary pool **{pool.upper()}** has recovered. Serving normal traffic."
            send_slack_alert(title, message, alert_type="recovery")
        last_pool = pool

    # --- High Error Rate Detection ---
    is_error = status.startswith("5")
    recent_requests.append(is_error)

    if len(recent_requests) < WINDOW_SIZE:
        return

    error_count = sum(recent_requests)
    error_rate = (error_count / WINDOW_SIZE) * 100

    if error_rate > ERROR_RATE_THRESHOLD:
        title = "📈 HIGH ERROR RATE 📈"
        message = (
            f"Upstream 5xx error rate is **{error_rate:.2f}%** "
            f"over the last {WINDOW_SIZE} requests "
            f"(Threshold: {ERROR_RATE_THRESHOLD}%). "
            f"Currently active pool: **{pool.upper()}**"
        )
        send_slack_alert(title, message, alert_type="error_rate")

if __name__ == "__main__":
    print("--- Log Watcher Service Started ---")
    print(f"Monitoring log file: {LOG_FILE}")
    print(f"Error Threshold: > {ERROR_RATE_THRESHOLD}% over {WINDOW_SIZE} requests")
    print(f"Maintenance Mode: {MAINTENANCE_MODE}")

    if not SLACK_WEBHOOK_URL:
        print("\nWARNING: SLACK_WEBHOOK_URL is not set. Alerts will be printed to console only.\n")

    while not os.path.exists(LOG_FILE):
        print("Log file not found, waiting 5 seconds...")
        time.sleep(5)

    print("Log file found. Tailing for new entries...")
    for line in tailer.follow(open(LOG_FILE)):
        process_log_line(line)
