# Chrome Plugin - Data Transfer Integration

This document describes the new data transfer functionality that allows seamless transfer of EIR data from the Chrome plugin to eir.space.

## Overview

The plugin now supports two modes of operation:
1. **Download Only**: Traditional file download (txt and eir files)
2. **View on eir.space**: Seamless data transfer to eir.space for immediate viewing

## Architecture

### Files Added/Modified

- `data-transfer.js` - New module handling PostMessage communication
- `content.js` - Updated with new UI and integration
- `manifest.json` - Updated to include data-transfer.js
- `styles.css` - Updated with action button styles
- `eir-space-demo.html` - Demo page showing eir.space integration

### Data Flow

1. **Data Extraction**: Plugin extracts journal data from 1177.se
2. **Data Storage**: Data is stored locally with unique key and expiration
3. **Transfer Initiation**: User clicks "View on eir.space" button
4. **PostMessage Communication**: Plugin opens eir.space and transfers data via PostMessage
5. **Data Display**: eir.space receives and displays the data

## Key Features

### Zero Server Storage
- Data never leaves the user's browser
- No server-side data handling required
- Privacy-first approach

### Secure Communication
- Origin verification for PostMessage
- Unique key generation for data sessions
- Automatic data expiration (24 hours)

### User Experience
- One-click transfer to eir.space
- Visual feedback during transfer
- Fallback options if transfer fails

## Technical Implementation

### DataTransferManager Class

```javascript
const dataTransferManager = new DataTransferManager();
await dataTransferManager.storeEirData(journalEntries);
const eirUrl = await dataTransferManager.transferToEirSpace();
```

### PostMessage Protocol

**Plugin → eir.space:**
```javascript
{
  type: 'EIR_DATA_RESPONSE',
  key: 'eir_data_1234567890_abc123',
  data: '{"metadata": {...}, "entries": [...]}',
  timestamp: 1234567890
}
```

**eir.space → Plugin:**
```javascript
{
  type: 'REQUEST_EIR_DATA',
  key: 'eir_data_1234567890_abc123'
}
```

### Security Measures

1. **Origin Verification**: Only accept messages from trusted origins
2. **Key Validation**: Verify data keys match between requests
3. **Data Expiration**: Automatic cleanup after 24 hours
4. **Error Handling**: Graceful fallbacks for failed transfers

## Usage Instructions

### For Users

1. Visit 1177.se journal page
2. Click the floating "Download Journals" button
3. Wait for data extraction to complete
4. Choose your action:
   - **📥 Download Files**: Traditional file download
   - **👁️ View on eir.space**: Seamless transfer to eir.space

### For Developers

#### Testing the Integration

1. Load the plugin in Chrome
2. Visit a 1177.se journal page
3. Extract data using the plugin
4. Click "View on eir.space" button
5. Verify data appears in eir.space demo page

#### Customizing eir.space URL

Update the `eirSpaceUrl` in `data-transfer.js`:

```javascript
this.eirSpaceUrl = 'https://your-eir-space-domain.com';
```

#### Handling Different Extension IDs

Update the `pluginOrigin` in `eir-space-demo.html`:

```javascript
this.pluginOrigin = 'chrome-extension://your-actual-extension-id';
```

## Error Handling

### Common Issues

1. **Popup Blockers**: May prevent eir.space from opening
2. **Extension ID Mismatch**: Plugin origin must match exactly
3. **Data Expiration**: Data expires after 24 hours
4. **Network Issues**: Fallback to file download

### Debugging

Enable console logging to debug issues:

```javascript
// In data-transfer.js
console.log('Data stored with key:', this.dataKey);
console.log('Transferring to:', eirUrl);

// In eir-space-demo.html
console.log('Received data:', this.eirData);
```

## Future Enhancements

- [ ] Support for multiple data sessions
- [ ] Data compression for large exports
- [ ] Offline data persistence
- [ ] Integration with existing eir-viewer React app
- [ ] Mobile app support via deep linking

## Security Considerations

- Data is only stored locally in browser
- No server-side data processing
- Automatic data expiration
- Origin verification for all communications
- No permanent data storage on eir.space servers

This implementation provides a privacy-first, seamless user experience while maintaining security and reliability.
