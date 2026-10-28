3. Obtaining Credentials

A. Google Play Console

Google Play statistics are retrieved from the automated Google Cloud Storage (GCS) export bucket created by Play Console.

Find your GCS Bucket ID:

Log in to Google Play Console.

Go to Download reports -> Statistics.

Copy your Cloud Storage URI from the top of the page (e.g., gs://pubsite_prod_rev_...).

Use the bucket string (without gs://) for GOOGLE_PLAY_BUCKET.

Create a Service Account:

Go to the Google Cloud Console.

Create a project (or select an existing one).

Go to IAM & Admin -> Service Accounts and create a service account.

Create a JSON Key for this service account, download it, and set GOOGLE_PLAY_SA_JSON to its path.

Grant Access in Play Console:

Go to Google Play Console -> Users and permissions.

Click Invite new users and enter your service account email.

Under Account permissions, grant View app information and download bulk reports.

Send the invite. (Note: Permission propagation in GCS can take up to 24-48 hours).

B. Apple App Store Connect

Apple reports use API key authentication to retrieve Sales & Trends data.

Generate API Key:

Log in to App Store Connect.

Go to Users and Access -> Integrations (or Keys / App Store Connect API).

Click + to add a key. Name it (e.g. Installs Reporter) and set Access to Finance or Sales.

Download the .p8 private key file (you can only download it once). Set APPLE_PRIVATE_KEY_PATH to its path.

Note the Key ID (APPLE_KEY_ID).

Note the Issuer ID at the top of the page (APPLE_ISSUER_ID).

Find Vendor Number:

In App Store Connect, go to Reports -> Sales and Trends.

Your Vendor Number (8-digit number starting with 8) is displayed at the top left under your account name. Set APPLE_VENDOR_NUMBER.

4. Usage

Run a dry run to check data fetching without sending a WhatsApp message:

python app_installs_report.py --dry-run


Fetch metrics and send the message via WhatsApp:

python app_installs_report.py

