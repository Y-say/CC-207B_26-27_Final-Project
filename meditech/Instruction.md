# Flutter Setup Guide (VS Code)

## Installations

### 1. Install Flutter SDK

Download Flutter and extract it to:

```text
C:\src\flutter
```

Add Flutter to PATH:

```text
C:\src\flutter\bin
```

Verify:

```bash
flutter doctor
```

---

### 2. Install VS Code Extensions

Install:

- Flutter
- Dart

---

### 3. Install Android SDK Command-line Tools

Download Android Command-line Tools.

Create the following structure:

```text
C:\Users\<username>\AppData\Local\Android\Sdk\cmdline-tools\latest
```

Move all extracted files into `latest`:

```text
cmdline-tools
└─ latest
   ├─ bin
   ├─ lib
   ├─ NOTICE.txt
   └─ source.properties
```

---

### 4. Configure Android SDK

Set Android SDK path:

```bash
flutter config --android-sdk "C:\Users\<username>\AppData\Local\Android\Sdk"
```

Set environment variables:

```text
ANDROID_HOME=C:\Users\<username>\AppData\Local\Android\Sdk
ANDROID_SDK_ROOT=C:\Users\<username>\AppData\Local\Android\Sdk
```

Add to PATH:

```text
C:\Users\<username>\AppData\Local\Android\Sdk\platform-tools
C:\Users\<username>\AppData\Local\Android\Sdk\cmdline-tools\latest\bin
```

Restart VS Code.

---

### 5. Install Required Android Packages

Run:

```powershell
& "C:\Users\<username>\AppData\Local\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

Accept licenses:

```bash
flutter doctor --android-licenses
```

---

### 6. Create and Run Project

Create project:

```bash
flutter create meditech
```

Open project:

```bash
cd meditech
```

Run project:

```bash
flutter run
```

---

# Troubleshooting

## Error: Unable to locate Android SDK

Run:

```bash
flutter config --android-sdk "C:\Users\<username>\AppData\Local\Android\Sdk"
```

Verify:

```bash
flutter doctor
```

---

## Error: sdkmanager is not recognized

Check if sdkmanager exists:

```powershell
Get-ChildItem "C:\Users\<username>\AppData\Local\Android\Sdk" -Recurse -Filter sdkmanager.bat
```

Run it using its full path:

```powershell
& "C:\Users\<username>\AppData\Local\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" --list
```

---

## Error: Wrong cmdline-tools Structure

❌ Wrong

```text
cmdline-tools
├─ bin
├─ lib
```

✅ Correct

```text
cmdline-tools
└─ latest
   ├─ bin
   ├─ lib
```

Move all files into the `latest` folder.

---

## Error: SDK Folder Contains Only cmdline-tools

❌ Incomplete

```text
Sdk
└─ cmdline-tools
```

✅ Required

```text
Sdk
├─ build-tools
├─ platform-tools
├─ platforms
└─ cmdline-tools
```

Install missing packages using `sdkmanager`.

---

## Verify Final Setup

```bash
flutter doctor -v
```

Expected:

```text
[✓] Flutter
[✓] Android toolchain
[✓] VS Code
```


This version contains only the installation steps and the specific errors/fixes you encountered.