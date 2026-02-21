# Chrome Extension Publishing Guide

## Step 1: Create Extension Package

### Required Files:
- `manifest.json` ✅ (already created)
- `content.js` ✅ (already created) 
- `styles.css` ✅ (already created)
- `icon16.png` ✅ (already created)
- `icon48.png` ✅ (already created)
- `icon128.png` ✅ (already created)

### Create these additional files:

#### 1. Create `popup.html` (optional but recommended):
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { width: 300px; padding: 20px; font-family: Arial, sans-serif; }
        h1 { color: #667eea; font-size: 18px; }
        p { color: #666; font-size: 14px; }
        .button { background: #667eea; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
    </style>
</head>
<body>
    <h1>1177 Journal Downloader</h1>
    <p>Download your complete medical journal from 1177.se</p>
    <button class="button" onclick="window.open('https://journalen.1177.se/JournalCategories/JournalOverview')">Open Journal</button>
</body>
</html>
```

#### 2. Update `manifest.json` to include popup:
```json
{
  "manifest_version": 3,
  "name": "1177 Journal Downloader",
  "version": "1.0.0",
  "description": "Download and structure patient journals from 1177.se",
  "permissions": [
    "activeTab",
    "storage"
  ],
  "host_permissions": [
    "https://journalen.1177.se/*"
  ],
  "content_scripts": [
    {
      "matches": ["https://journalen.1177.se/*"],
      "js": ["content.js"],
      "css": ["styles.css"],
      "run_at": "document_end"
    }
  ],
  "action": {
    "default_popup": "popup.html",
    "default_title": "1177 Journal Downloader"
  },
  "icons": {
    "16": "icon16.png",
    "48": "icon48.png",
    "128": "icon128.png"
  }
}
```

## Step 2: Package the Extension

1. **Create a ZIP file** containing only these files:
   - manifest.json
   - content.js
   - styles.css
   - popup.html
   - icon16.png
   - icon48.png
   - icon128.png

2. **Exclude these files** from the ZIP:
   - README.md
   - icon-generator.html
   - page_source_journal.html
   - package-instructions.md

## Step 3: Chrome Web Store Publishing

### Prerequisites:
- Google account
- $5 one-time registration fee
- Valid payment method

### Publishing Process:

1. **Go to Chrome Web Store Developer Dashboard**
   - Visit: https://chrome.google.com/webstore/devconsole/
   - Sign in with Google account
   - Pay $5 registration fee (one-time)

2. **Upload Your Extension**
   - Click "Add new item"
   - Upload your ZIP file
   - Fill out required information

3. **Required Information:**
   - **Name**: "1177 Journal Downloader"
   - **Summary**: "Download your complete medical journal from 1177.se"
   - **Description**: Detailed description of functionality
   - **Category**: "Productivity"
   - **Language**: "English" and "Swedish"
   - **Screenshots**: Take screenshots of the extension in action
   - **Privacy Policy**: Required for extensions that handle user data

4. **Privacy Policy Requirements:**
   Since your extension accesses medical data, you need a privacy policy explaining:
   - What data is collected
   - How it's used
   - That data stays on user's device
   - No data is sent to external servers

## Step 4: Review Process

- **Review time**: 1-3 business days
- **Common rejection reasons**:
  - Missing privacy policy
  - Unclear functionality description
  - Security concerns
  - Policy violations

## Step 5: After Approval

- Extension goes live on Chrome Web Store
- Users can install with one click
- You can update the extension anytime
- Analytics available in developer dashboard

## Important Notes:

⚠️ **Medical Data Considerations:**
- This extension handles sensitive medical information
- Ensure compliance with GDPR and medical data regulations
- Consider adding data encryption options
- Make it clear that users are responsible for data security

⚠️ **Legal Considerations:**
- Check if this violates 1177.se's terms of service
- Consider reaching out to 1177.se for permission
- May need legal review for medical data handling

## Alternative Distribution:

If Chrome Web Store approval is difficult:
1. **Direct distribution** - Share ZIP file directly
2. **Developer mode** - Users install manually
3. **GitHub releases** - Host on GitHub with installation instructions
