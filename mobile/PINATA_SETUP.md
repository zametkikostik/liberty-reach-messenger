# 🔐 PINATA API KEY SETUP GUIDE

## Step 1: Create Pinata Account

1. Go to https://pinata.cloud
2. Click "Get Started" → "Sign Up"
3. Complete registration with email
4. Verify your email address

---

## Step 2: Get API Keys

### Option A: JWT Authentication (Recommended)

1. Login to Pinata Dashboard
2. Go to **Settings** → **API Keys**
3. Click **"Create New Key"**
4. Select key type: **"Admin"** (for full access)
5. Set permissions:
   - ✅ `pin_fileToIPFS` (upload files)
   - ✅ `pin_pinByHash` (pin by hash)
   - ✅ `unpin` (delete files)
   - ✅ `userPinPolicy` (manage policies)
6. Click **"Create Key"**
7. **Copy the JWT token** (shown only once!)

### Option B: API Key + Secret

1. Same as above, but select **"API Key"** type
2. Copy both:
   - `pinata_api_key`
   - `pinata_secret_api_key`

---

## Step 3: Configure Flutter App

### Method 1: Direct in Code (Development Only)

Edit `mobile/lib/services/storage_service.dart`:

```dart
class StorageService {
  // Replace with your actual keys
  static const String _pinataJwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
  static const String _pinataApiKey = 'a1b2c3d4e5f6...';
  static const String _pinataSecretKey = 'secret_abc123def456...';
```

⚠️ **WARNING:** Never commit these keys to Git!

---

### Method 2: Environment Variables (Production)

1. Create `.env` file in `mobile/` directory:

```env
PINATA_JWT=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
PINATA_API_KEY=a1b2c3d4e5f6...
PINATA_SECRET_KEY=secret_abc123def456...
```

2. Add `flutter_dotenv` to `pubspec.yaml`:

```yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

3. Update `storage_service.dart`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StorageService {
  static const String _pinataJwt = String.fromEnvironment('PINATA_JWT');
  
  Future<void> init() async {
    await dotenv.load(fileName: ".env");
    _pinataJwt = dotenv.env['PINATA_JWT']!;
  }
}
```

4. Add `.env` to `.gitignore`:

```gitignore
# Environment variables
.env
.env.local
.env.*.local
```

---

## Step 4: Test Upload

```dart
import 'package:image_picker/image_picker.dart';
import 'package:liberty_reach/services/storage_service.dart';

final storageService = StorageService();
final picker = ImagePicker();

// Pick image
final XFile? image = await picker.pickImage(source: ImageSource.gallery);

if (image != null) {
  try {
    // Upload avatar (public)
    final cid = await storageService.uploadAvatar(File(image.path));
    print('✅ Uploaded: $cid');
    
    // Or upload encrypted (private)
    final result = await storageService.uploadEncryptedFile(File(image.path));
    print('✅ Encrypted CID: ${result['cid']}');
    print('✅ Nonce: ${result['nonce']}');
  } catch (e) {
    print('❌ Upload failed: $e');
  }
}
```

---

## Step 5: Verify on Pinata Dashboard

1. Go to https://app.pinata.cloud/files
2. You should see your uploaded files
3. Click on file → Copy CID
4. Access via gateway: `https://gateway.pinata.cloud/ipfs/YOUR_CID`

---

## 🔐 Security Best Practices

1. **NEVER commit API keys to Git**
   - Add `.env` to `.gitignore`
   - Use environment variables in CI/CD

2. **Rotate keys regularly**
   - Pinata Dashboard → Settings → API Keys → Revoke
   - Generate new keys

3. **Use JWT instead of Key+Secret**
   - More secure
   - Easier to rotate

4. **Limit key permissions**
   - Only grant necessary permissions
   - Use separate keys for dev/staging/production

5. **Encrypt sensitive files**
   - Use `uploadEncryptedFile()` for private data
   - Avatars can be public

---

## 📊 Pricing

Pinata Free Tier:
- ✅ 1 GB storage
- ✅ Unlimited uploads
- ✅ Gateway access
- ❌ No custom gateway

Paid Plans:
- $20/month: 100 GB
- $80/month: 500 GB
- Custom: Enterprise

---

## 🆘 Troubleshooting

### Error: "Invalid JWT"
- Check JWT token is copied correctly (no spaces)
- Ensure JWT hasn't expired
- Regenerate if needed

### Error: "File too large"
- Free tier: max 1 GB total
- Compress images before upload
- Use `image_cropper` to resize

### Error: "Network request failed"
- Check internet connection
- Verify Pinata API is up: https://status.pinata.cloud

---

## 📞 Support

- Pinata Docs: https://docs.pinata.cloud
- Discord: https://discord.gg/pinata
- Email: support@pinata.cloud

---

**Current Configuration:**

File: `mobile/lib/services/storage_service.dart`

```dart
static const String _pinataJwt = 'YOUR_PINATA_JWT'; // ← Replace this
```

**Action Required:** Replace `YOUR_PINATA_JWT` with your actual JWT token from Pinata Dashboard.
