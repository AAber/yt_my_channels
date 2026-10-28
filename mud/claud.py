#!/usr/bin/env python3
"""
app_installs_report.py
======================

Collects install numbers for every app in your Google Play and Apple App Store
accounts and posts one summary message to a WhatsApp group using Mudslide.

What the numbers mean (the two stores expose different things):

  Google Play  "Active Device Installs": devices that have the app installed
               and were online at least once in the last 30 days. Read from the
               bulk CSV reports Play Console exports to your Cloud Storage
               bucket (stats/installs/*_overview.csv).

  App Store    Apple's API has no single "active installs" number. This script
               reports first-time downloads for the last N days (default 30)
               from Sales & Trends. Active-device data exists only in Apple's
               much heavier Analytics Reports API.

Configuration comes from environment variables, or from a .env file next to
this script (override the location with ENV_FILE). See SETUP.md for how to
create every credential.

Usage:
    python app_installs_report.py               # fetch + send to WhatsApp
    python app_installs_report.py --dry-run     # fetch + print, don't send
    python app_installs_report.py --only play   # just Google Play
    python app_installs_report.py --only apple  # just the App Store

Dependencies:
    pip install requests PyJWT cryptography google-auth
    npm install -g mudslide
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import gzip
import io
import json
import logging
import os
import re
import shlex
import subprocess
import sys
import time
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Optional
from urllib.parse import quote

import requests

log = logging.getLogger("app_installs_report")


class ConfigError(Exception):
    """A required setting is missing."""


@dataclass
class AppCount:
    name: str
    count: int
    as_of: str = ""


# --------------------------------------------------------------------------
# Configuration helpers
# --------------------------------------------------------------------------
def load_dotenv(path: Path) -> None:
    """Minimal .env loader (KEY=VALUE lines). Real environment variables win."""
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        if key.startswith("export "):
            key = key[len("export "):].strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        os.environ.setdefault(key, value)


def env(name: str, default: Optional[str] = None, required: bool = False) -> Optional[str]:
    value = os.environ.get(name, default)
    if required and not value:
        raise ConfigError(f"Missing required setting {name} (see SETUP.md)")
    return value


# --------------------------------------------------------------------------
# Google Play: bulk "installs overview" CSV reports in Cloud Storage
# --------------------------------------------------------------------------
PLAY_SCOPE = "https://www.googleapis.com/auth/devstorage.read_only"
GCS_API = "https://storage.googleapis.com/storage/v1/b"
OVERVIEW_RE = re.compile(
    r"^stats/installs/installs_(?P<pkg>.+)_(?P<ym>\d{6})_overview\.csv$"
)
ACTIVE_COLUMN = "Active Device Installs"


def play_session():
    """Authenticated HTTP session using the service-account JSON key."""
    from google.auth.transport.requests import AuthorizedSession
    from google.oauth2 import service_account

    key_file = env("GOOGLE_PLAY_SA_JSON", required=True)
    creds = service_account.Credentials.from_service_account_file(
        key_file, scopes=[PLAY_SCOPE]
    )
    return AuthorizedSession(creds)


def play_bucket() -> str:
    """Accepts 'pubsite_prod_rev_123' or a pasted 'gs://pubsite_prod_rev_123/stats/...'."""
    raw = env("GOOGLE_PLAY_BUCKET", required=True).strip()
    raw = re.sub(r"^gs://", "", raw)
    return raw.split("/")[0]


def gcs_get(session, url: str, **kwargs) -> requests.Response:
    r = session.get(url, timeout=120, **kwargs)
    if r.status_code == 403:
        raise RuntimeError(
            "Cloud Storage returned 403: the service account cannot read the Play "
            "bucket. Check it was invited in Play Console with 'View app information "
            "and download bulk reports' (can take up to 24-48 h to take effect)."
        )
    if r.status_code == 404:
        raise RuntimeError(
            "Cloud Storage returned 404: check GOOGLE_PLAY_BUCKET "
            "(it starts with pubsite_prod_rev_)."
        )
    r.raise_for_status()
    return r


def list_overview_files(session, bucket: str) -> dict[str, list[tuple[str, str]]]:
    """Return {package: [(YYYYMM, object_name), ...]} newest month first."""
    files: dict[str, list[tuple[str, str]]] = defaultdict(list)
    token = None
    while True:
        params = {
            "prefix": "stats/installs/installs_",
            "fields": "items(name),nextPageToken",
            "maxResults": 1000,
        }
        if token:
            params["pageToken"] = token
        data = gcs_get(session, f"{GCS_API}/{bucket}/o", params=params).json()
        for item in data.get("items", []):
            m = OVERVIEW_RE.match(item["name"])
            if m:
                files[m["pkg"]].append((m["ym"], item["name"]))
        token = data.get("nextPageToken")
        if not token:
            break
    for months in files.values():
        months.sort(reverse=True)
    return files


def download_object(session, bucket: str, name: str) -> bytes:
    url = f"{GCS_API}/{bucket}/o/{quote(name, safe='')}"
    return gcs_get(session, url, params={"alt": "media"}).content


def decode_report(raw: bytes) -> str:
    """Play CSV exports are normally UTF-16 with a BOM; handle UTF-8 as well."""
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        return raw.decode("utf-16")
    return raw.decode("utf-8-sig")


def latest_active_installs(csv_text: str) -> Optional[tuple[str, int]]:
    """Return (date, active_device_installs) for the newest row that has a value."""
    reader = csv.DictReader(io.StringIO(csv_text))
    if reader.fieldnames is None:
        return None
    reader.fieldnames = [f.strip() for f in reader.fieldnames]
    if ACTIVE_COLUMN not in reader.fieldnames:
        raise ValueError(
            f"Column '{ACTIVE_COLUMN}' not found; got: {', '.join(reader.fieldnames)}"
        )
    best: Optional[tuple[str, int]] = None
    for row in reader:
        raw = (row.get(ACTIVE_COLUMN) or "").strip().replace(",", "")
        if not raw.isdigit():
            continue
        date = (row.get("Date") or "").strip()
        if best is None or date >= best[0]:
            best = (date, int(raw))
    return best


def fetch_play() -> list[AppCount]:
    session = play_session()
    bucket = play_bucket()
    names = json.loads(env("PLAY_APP_NAMES", "{}") or "{}")
    exclude = {p.strip() for p in (env("PLAY_EXCLUDE_PACKAGES", "") or "").split(",") if p.strip()}
    max_stale = int(env("PLAY_MAX_STALE_DAYS", "60"))
    today = dt.date.today()

    results: list[AppCount] = []
    for pkg, months in sorted(list_overview_files(session, bucket).items()):
        if pkg in exclude:
            continue
        found = None
        # Newest month first; at the start of a month that file may still be empty.
        for _ym, obj in months[:3]:
            found = latest_active_installs(decode_report(download_object(session, bucket, obj)))
            if found:
                break
        if not found:
            log.warning("No install data found for %s", pkg)
            continue
        try:
            age = (today - dt.date.fromisoformat(found[0])).days
            if age > max_stale:
                log.info("Skipping %s: newest data is %d days old", pkg, age)
                continue
        except ValueError:
            pass  # unexpected date format: keep the app, skip the staleness check
        results.append(AppCount(names.get(pkg, pkg), found[1], found[0]))
    return results


# --------------------------------------------------------------------------
# Apple: App Store Connect API (JWT auth) + Sales & Trends reports
# --------------------------------------------------------------------------
ASC_API = "https://api.appstoreconnect.apple.com"
# First-time downloads. Re-downloads (3, 3F, 3T) and updates (7, 7F, 7T) are excluded.
DEFAULT_PRODUCT_TYPES = "1,1F,1T,F1"


def apple_token() -> str:
    import jwt  # PyJWT

    key_id = env("APPLE_KEY_ID", required=True)
    issuer = env("APPLE_ISSUER_ID", required=True)
    key_path = env("APPLE_PRIVATE_KEY_PATH", required=True)
    private_key = Path(key_path).expanduser().read_text(encoding="utf-8")
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"},
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def asc_error(r: requests.Response) -> str:
    try:
        errors = r.json().get("errors", [])
        text = "; ".join(f"{e.get('title')}: {e.get('detail')}" for e in errors)
        return text or r.text[:300]
    except ValueError:
        return r.text[:300]


def apple_list_apps(headers: dict) -> dict[str, str]:
    """Return {apple_id: app_name} for every app in the account."""
    apps: dict[str, str] = {}
    url: Optional[str] = f"{ASC_API}/v1/apps"
    params: Optional[dict] = {"limit": 200, "fields[apps]": "name,bundleId"}
    while url:
        r = requests.get(url, headers=headers, params=params, timeout=60)
        if r.status_code != 200:
            raise RuntimeError(f"App Store Connect {r.status_code}: {asc_error(r)}")
        body = r.json()
        for app in body.get("data", []):
            apps[app["id"]] = app["attributes"]["name"]
        url = body.get("links", {}).get("next")
        params = None  # the 'next' link already carries the query string
    return apps


def apple_daily_downloads(
    headers: dict, vendor: str, day: dt.date, product_types: set[str]
) -> tuple[dict[str, int], dict[str, str]]:
    """First-time download units per Apple ID for one day, plus titles seen."""
    params = {
        "filter[frequency]": "DAILY",
        "filter[reportType]": "SALES",
        "filter[reportSubType]": "SUMMARY",
        "filter[vendorNumber]": vendor,
        "filter[reportDate]": day.isoformat(),
    }
    hdrs = {**headers, "Accept": "application/a-gzip"}
    r = None
    for attempt in range(3):
        r = requests.get(f"{ASC_API}/v1/salesReports", headers=hdrs, params=params, timeout=120)
        if r.status_code in (429, 500, 502, 503):
            time.sleep(5 * (attempt + 1))
            continue
        break
    if r.status_code == 404:  # no report for that day (yet)
        return {}, {}
    if r.status_code != 200:
        raise RuntimeError(f"App Store Connect {r.status_code}: {asc_error(r)}")

    try:
        text = gzip.decompress(r.content).decode("utf-8")
    except OSError:
        text = r.content.decode("utf-8")

    units: dict[str, int] = defaultdict(int)
    titles: dict[str, str] = {}
    for row in csv.DictReader(io.StringIO(text), delimiter="\t"):
        if (row.get("Product Type Identifier") or "").strip() not in product_types:
            continue
        apple_id = (row.get("Apple Identifier") or "").strip()
        if not apple_id:
            continue
        units[apple_id] += int(float(row.get("Units") or 0))
        titles[apple_id] = (row.get("Title") or "").strip()
    return units, titles


def fetch_apple() -> tuple[list[AppCount], int]:
    """Return (per-app downloads over the window, number of days that had a report)."""
    vendor = env("APPLE_VENDOR_NUMBER", required=True)
    days = int(env("APPLE_DAYS", "30"))
    product_types = {t.strip() for t in env("APPLE_PRODUCT_TYPES", DEFAULT_PRODUCT_TYPES).split(",")}
    headers = {"Authorization": f"Bearer {apple_token()}"}

    apps = apple_list_apps(headers)
    totals: dict[str, int] = defaultdict(int)
    titles: dict[str, str] = {}
    days_with_data = 0
    today = dt.date.today()

    for back in range(1, days + 1):
        day = today - dt.timedelta(days=back)
        units, day_titles = apple_daily_downloads(headers, vendor, day, product_types)
        if units:
            days_with_data += 1
        for apple_id, n in units.items():
            totals[apple_id] += n
        titles.update(day_titles)

    names = {**titles, **apps}  # App Store Connect names win over report titles
    results = [
        AppCount(names.get(i, i), totals.get(i, 0))
        for i in sorted(set(apps) | set(totals))
    ]
    return results, days_with_data


# --------------------------------------------------------------------------
# Message + WhatsApp (Mudslide)
# --------------------------------------------------------------------------
def build_message(
    play: Optional[list[AppCount]],
    apple: Optional[list[AppCount]],
    apple_days: int,
    errors: list[str],
) -> str:
    lines = [f"📊 *App installs report* - {dt.date.today():%Y-%m-%d}", ""]

    def section(title: str, items: list[AppCount]) -> None:
        lines.append(title)
        if not items:
            lines.append("• (no data found)")
        for a in sorted(items, key=lambda a: (-a.count, a.name.lower())):
            lines.append(f"• {a.name}: {a.count:,}")
        lines.append(f"*Total: {sum(a.count for a in items):,}*")
        lines.append("")

    if play is not None:
        section("🤖 *Google Play* - active installs", play)
    if apple is not None:
        section(f"🍎 *App Store* - downloads, last {apple_days} days", apple)
    for err in errors:
        lines.append(f"⚠️ {err}")
    return "\n".join(lines).strip()


def send_whatsapp(message: str) -> None:
    group = env("WHATSAPP_GROUP_ID", required=True).strip()
    jid = group if "@" in group else f"{group}@g.us"
    numeric = jid.split("@")[0]

    base = shlex.split(env("MUDSLIDE_BIN", "mudslide"))
    cache_dir = env("MUDSLIDE_CACHE_DIR")
    if cache_dir:
        base += ["-c", cache_dir]

    # Current Mudslide: `send <jid>`. Older releases: `send-group <numeric-id>`.
    attempts = [base + ["send", jid, message], base + ["send-group", numeric, message]]
    failures = []
    for cmd in attempts:
        try:
            proc = subprocess.run(cmd[:-1] + ["<message>"] and cmd, capture_output=True, text=True, timeout=180)
        except FileNotFoundError:
            raise RuntimeError(
                f"Could not run '{base[0]}'. Install it with 'npm install -g mudslide' "
                "or set MUDSLIDE_BIN to its full path."
            )
        except subprocess.TimeoutExpired:
            failures.append(f"{cmd[-3 if len(cmd) > 3 else 1]}: timed out")
            continue
        if proc.returncode == 0:
            log.info("WhatsApp message sent (%s)", cmd[len(base)])
            return
        failures.append(f"`{cmd[len(base)]}` exited {proc.returncode}: {(proc.stderr or proc.stdout).strip()[:300]}")
    raise RuntimeError("Mudslide failed. " + " | ".join(failures) +
                       " (If you see an auth/login error, run `mudslide login` again.)")


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Send app install counts to a WhatsApp group.")
    parser.add_argument("--dry-run", action="store_true", help="print the message, do not send it")
    parser.add_argument("--only", choices=["play", "apple"], help="query only one store")
    parser.add_argument("-v", "--verbose", action="store_true", help="debug logging")
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        stream=sys.stderr,
    )
    load_dotenv(Path(os.environ.get("ENV_FILE", Path(__file__).with_name(".env"))))

    play_on = args.only == "play" or (args.only is None and bool(env("GOOGLE_PLAY_SA_JSON")))
    apple_on = args.only == "apple" or (args.only is None and bool(env("APPLE_KEY_ID")))
    if not (play_on or apple_on):
        log.error("No store is configured. Set the Google Play and/or Apple settings (see SETUP.md).")
        return 2

    play: Optional[list[AppCount]] = None
    apple: Optional[list[AppCount]] = None
    apple_days = int(env("APPLE_DAYS", "30"))
    errors: list[str] = []

    if play_on:
        try:
            play = fetch_play()
            log.info("Google Play: %d apps", len(play))
        except Exception as exc:  # one store failing must not block the other
            log.error("Google Play failed: %s", exc)
            log.debug("details", exc_info=True)
            errors.append(f"Google Play failed: {exc}"[:300])

    if apple_on:
        try:
            apple, days_with_data = fetch_apple()
            log.info("App Store: %d apps (%d/%d days had reports)", len(apple), days_with_data, apple_days)
        except Exception as exc:
            log.error("App Store failed: %s", exc)
            log.debug("details", exc_info=True)
            errors.append(f"App Store failed: {exc}"[:300])

    if play is None and apple is None:
        log.error("Every store failed; nothing to send.")
        return 1

    message = build_message(play, apple, apple_days, errors)
    print(message)
    if args.dry_run:
        return 0

    try:
        send_whatsapp(message)
    except Exception as exc:
        log.error("%s", exc)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
