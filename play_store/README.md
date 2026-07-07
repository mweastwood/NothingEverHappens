# Google Play Data Safety Questionnaire Management

This directory contains the Google Play Store Data Safety Questionnaire CSV configuration and the automation script to automatically upload it during production releases.

## 📋 How it Works

1. **Official Format**: Because Google Play's CSV structure depends on your app's specific declarations, you must use the official template exported directly from your Play Console.
2. **Repository Tracked**: Keep `play_store/data_safety.csv` updated in this repository.
3. **Automated Upload**: During release, the GitHub Actions deployment workflow executes `play_store/upload_data_safety.js` using your Play Store service account credentials to sync the declarations automatically.

---

## 🛠️ Step-by-Step Setup

### Step 1: Export your Official Template
1. Log in to the [Google Play Console](https://play.google.com/console/).
2. Select your app (`com.mweastwood.nothing_ever_happens`).
3. In the left-hand menu, navigate to **Policy > App content**.
4. Find the **Data safety** section and click **Start** or **Manage**.
5. Near the top right of the page, click **Export to CSV**.
6. Save the downloaded file as `play_store/data_safety.csv` in this repository, overwriting the placeholder.

### Step 2: Fill Out/Modify Answers
* Open `play_store/data_safety.csv` in a spreadsheet editor or text editor.
* Update your declarations (marking `TRUE` or `FALSE` for various data collection and sharing questions).
* Commit and push your changes to your feature branch or `main`.

---

## 🚀 Local Automation Run (Optional)

If you want to manually update the data safety settings on Google Play from your local machine, you can run:

```bash
export SERVICE_ACCOUNT_JSON='{...your service account credentials json...}'
export CSV_PATH='./play_store/data_safety.csv'
export PACKAGE_NAME='com.mweastwood.nothing_ever_happens'

node play_store/upload_data_safety.js
```
