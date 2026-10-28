# Setup Guide for App Installs Report Script

This guide details how to obtain credentials for Google Play, Apple App Store Connect, and configure Mudslide for WhatsApp notifications.

---

## 1. Prerequisites & Dependencies

### Python Setup
Ensure Python 3.8+ is installed, then install the required Python packages:
```bash
pip install requests PyJWT cryptography google-auth
```

### WhatsApp (Mudslide) Setup
The script uses `/usr/bin/npx mudslide` to send messages.

1. Perform a one-time login to pair Mudslide with your WhatsApp account:
   ```bash
   /usr/bin/npx mudslide login
   ```
2. Scan the generated QR code using your WhatsApp app (Settings -> Linked Devices).
3. Verify messaging yourself:
   ```bash
   /usr/bin/npx mudslide send me "Test message"
   ```

---

## 2. Configuration (`.env` file)

Create a `.env` file in the same directory as `app_installs_report.py`:

```env
# ------------------------------------------------------------------------------
# Google Play Console Settings
# ------------------------------------------------------------------------------
GOOGLE_PLAY_SA_JSON="path/to/service-account-key.json"
GOOGLE_PLAY_BUCKET="pubsite_prod_rev_01234567899876543210"
# Optional JSON map to friendly app names:
PLAY_APP_NAMES='{"com.example.app": "My Cool App"}'
# Optional comma-separated packages to exclude:
PLAY_EXCLUDE_PACKAGES=""

# ------------------------------------------------------------------------------
# Apple App Store Connect Settings
# ------------------------------------------------------------------------------
APPLE_KEY_ID="ABC123XYZ"
APPLE_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
APPLE_PRIVATE_KEY_PATH="path/to/AuthKey_ABC123XYZ.p8"
APPLE_VENDOR_NUMBER="80000000"
APPLE_DAYS="30"

# ------------------------------------------------------------------------------
# WhatsApp / Mudslide Settings
# ------------------------------------------------------------------------------
MUDSLIDE_BIN="/usr/bin/npx mudslide"
# Target recipient: "me" or a WhatsApp Group ID (e.g. "12036301234567890@g.us")
WHATSAPP_GROUP_ID="me"
```

---

## 3. Obtaining Credentials

### A. Google Play Console

Google Play statistics are retrieved from the automated Google Cloud Storage (GCS) export bucket created by Play Console.

1. **Find your GCS Bucket ID**:
   - Log in to [Google Play Console](https://play.google.com/console).
   - Go to **Download reports** -> **Statistics**.
   - Copy your Cloud Storage URI from the top of the page (e.g., `gs://pubsite_prod_rev_...`).
   - Use the bucket string (without `gs://`) for `GOOGLE_PLAY_BUCKET`.

2. **Create a Service Account**:
   - Go to the [Google Cloud Console](https://console.cloud.google.com/).
   - Create a project (or select an existing one).
   - Go to **IAM & Admin** -> **Service Accounts** and create a service account.
   - Create a JSON Key for this service account, download it, and set `GOOGLE_PLAY_SA_JSON` to its path.

3. **Grant Access in Play Console**:
   - Go to Google Play Console -> **Users and permissions**.
   - Click **Invite new users** and enter your service account email.
   - Under **Account permissions**, grant **View app information and download bulk reports**.
   - Send the invite. *(Note: Permission propagation in GCS can take up to 24-48 hours)*.

---

### B. Apple App Store Connect

Apple reports use API key authentication to retrieve Sales & Trends data.

1. **Generate API Key**:
   - Log in to [App Store Connect](https://appstoreconnect.apple.com/).
   - Go to **Users and Access** -> **Integrations** (or **Keys** / **App Store Connect API**).
   - Click **+** to add a key. Name it (e.g. `Installs Reporter`) and set Access to **Finance** or **Sales**.
   - Download the `.p8` private key file (you can only download it once). Set `APPLE_PRIVATE_KEY_PATH` to its path.
   - Note the **Key ID** (`APPLE_KEY_ID`).
   - Note the **Issuer ID** at the top of the page (`APPLE_ISSUER_ID`).

2. **Find Vendor Number**:
   - In App Store Connect, go to **Reports** -> **Sales and Trends**.
   - Your **Vendor Number** (8-digit number starting with `8`) is displayed at the top left under your account name. Set `APPLE_VENDOR_NUMBER`.

---

## 4. Usage

Run a dry run to check data fetching without sending a WhatsApp message:
```bash
python app_installs_report.py --dry-run
```

Fetch metrics and send the message via WhatsApp:
```bash
python app_installs_report.py
```