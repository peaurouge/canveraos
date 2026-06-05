# How to Upload CanveraOS to GitHub and Build the ISO
### A plain-English guide for non-developers

---

## Part 1 — Create a GitHub Account (if you don't have one)

1. Open your browser and go to **[github.com](https://github.com)**
2. Click the big green **"Sign up"** button
3. Enter your email address, create a password, choose a username
4. Verify your email (GitHub sends you a confirmation email)
5. On the plan selection page, choose **"Free"** — this is enough to start

> ✅ **Free account is sufficient** for building CanveraOS IF your repository is **Public**. See the comparison table at the bottom of this guide.

---

## Part 2 — Install GitHub Desktop (the easy GUI app)

GitHub Desktop lets you upload files without typing any commands.

1. Go to **[desktop.github.com](https://desktop.github.com)**
2. Click **"Download for macOS"**
3. Open the downloaded file and drag GitHub Desktop to your Applications folder
4. Open GitHub Desktop
5. Sign in with your GitHub account (same username/password you just created)

---

## Part 3 — Create a New Repository on GitHub

A "repository" is just a folder on GitHub that stores your project.

1. In GitHub Desktop, click **"File"** → **"New Repository"**
2. Fill in the form:
   - **Name**: `CanveraOS`
   - **Description**: `Custom bootable OS for creative professionals`
   - **Local Path**: Click "Choose…" and select your **Desktop → Antigravity folder**
   - **Initialize with README**: ✅ Check this
   - **Visibility**: **Public** (required for free unlimited build minutes)
3. Click **"Create Repository"**

---

## Part 4 — Add Your CanveraOS Files

Now you need to move the CanveraOS files into the repository folder.

**The folder GitHub Desktop created is:**
```
/Users/mixedskills/Desktop/Antigravity/CanveraOS/
```

Your project files are already in this exact location — that's it! GitHub Desktop automatically tracks all files in this folder.

**Add your logo:**
1. Place your CanveraOS logo file into:
   - `theme/canvera-logo.png` (512×512 PNG)
   - Also copy it to `installer/calamares/branding/canvera-logo.png`

---

## Part 5 — Upload to GitHub (called "Publishing")

1. In GitHub Desktop, you'll see a list of all your project files on the left
2. In the bottom-left, you'll see a box that says **"Summary (required)"**
3. Type something like: `Initial CanveraOS project files`
4. Click the blue **"Commit to main"** button
5. Now click **"Publish repository"** (the button at the top)
6. A dialog appears:
   - **Name**: `CanveraOS` (already filled)
   - **Keep this code private**: ❌ **UNCHECK this** (must be Public for free build minutes)
7. Click **"Publish Repository"**

✅ **Your files are now on GitHub!** You can see them at:
`https://github.com/YOUR-USERNAME/CanveraOS`

---

## Part 6 — Run the Build (Trigger GitHub Actions)

This starts the cloud computer that builds your ISO.

1. Go to `https://github.com/YOUR-USERNAME/CanveraOS` in your browser
2. Click the **"Actions"** tab (top navigation bar)
3. On the left side, you'll see **"🏗️ Build CanveraOS ISO"**
4. Click on it
5. On the right side, you'll see **"Run workflow"** button — click it
6. A small panel drops down:
   - **ISO version**: Leave as `1.0.0`
   - **Create GitHub Release with the ISO?**: ✅ Yes (checked)
7. Click the green **"Run workflow"** button

---

## Part 7 — Watch the Build

1. A new row appears under the "Actions" tab with an orange dot 🟡
2. Click on it to watch the build progress
3. You'll see each step running in real time:
   - 🧹 Cleaning disk space (~2 min)
   - 🔧 Installing build tools (~3 min)
   - 🏗️ Building ISO (~60–90 min) ← this is the long one
   - 🚀 Creating release (~2 min)

**Total build time: approximately 75–95 minutes**

---

## Part 8 — Download Your ISO

When the build shows a green checkmark ✅:

### Option A — From GitHub Releases (Recommended)
1. Go to your repo main page
2. On the right side, click **"Releases"**
3. You'll see **"CanveraOS v1.0.0 — Aurora"**
4. Click the `.iso` file to download

### Option B — From Artifacts (Temporary, 7 days)
1. Click the **"Actions"** tab
2. Click the completed build
3. Scroll down to **"Artifacts"**
4. Click **"CanveraOS-1.0.0-amd64"** to download a zip containing the ISO

---

## Answers to Your Specific Questions

### ❓ Do I need a paid GitHub account?

| Feature | Free Account | Pro Account ($4/mo) |
|---|---|---|
| Build minutes (Public repo) | **Unlimited ✅** | Unlimited |
| Build minutes (Private repo) | 2,000 min/month | 3,000 min/month |
| Artifact storage | 500 MB | 1 GB |
| Releases storage | 2 GB per file | 2 GB per file |
| **Verdict** | **✅ Free is fine** | Only if you want private repo |

> **Bottom line**: A **free account** with a **public repository** is all you need. The build runs for free on GitHub's servers. The only thing you need to be careful about is file size (see below).

---

### ❓ How large will the ISO be?

| Component | Compressed size |
|---|---|
| Ubuntu 24.04 base kernel | ~120 MB |
| KDE Plasma 6 desktop | ~650 MB |
| All media codecs (GStreamer, FFmpeg) | ~200 MB |
| Applications (VLC, Steam, Telegram, etc.) | ~1.2 GB |
| CrossOver + Wine runtimes | ~400 MB |
| Fonts, wallpapers, theme | ~80 MB |
| **Total estimated ISO size** | **~2.5–3.5 GB** |

> Note: CrossOver downloads at install time (not baked in), and DaVinci Resolve is downloaded on first click — this keeps the ISO smaller.

**GitHub Release file limit: 2 GB per file**

If the ISO exceeds 2 GB, the workflow will automatically split it — or you can use a free file host like [Cloudflare R2](https://r2.cloudflare.com). I can set this up if needed.

---

### ❓ How long does the build take?

| Stage | Time |
|---|---|
| Disk cleanup | ~2 min |
| Install build tools | ~3 min |
| Download Ubuntu 24.04 base | ~8 min |
| Install KDE Plasma 6 | ~25 min |
| Install codecs | ~8 min |
| Install CrossOver | ~10 min |
| Install applications | ~15 min |
| Apply theme + config | ~5 min |
| Compress to SquashFS | ~12 min |
| Build ISO with GRUB | ~3 min |
| Upload to GitHub Release | ~5 min |
| **Total** | **~95 minutes** |

GitHub Actions has a **6-hour maximum** per job — we're well under that.

---

### ❓ How do I update the ISO after making changes?

1. Make your changes to the project files on your Mac
2. In GitHub Desktop: write a summary, click **"Commit to main"**, then **"Push origin"**
3. Go to GitHub → Actions → Run workflow again
4. New ISO is built automatically with your changes

---

## Troubleshooting

### Build failed: "Not enough disk space"
- The cleanup step freed less space than expected
- Solution: Open `.github/workflows/build-iso.yml`, add more cleanup steps, or contact me to optimize the build

### Build failed: "debootstrap error"
- The GitHub runner couldn't download Ubuntu packages
- Usually a temporary network issue — just run the workflow again

### ISO not appearing in Releases
- Check that you checked "Create GitHub Release with the ISO?" when triggering
- Large files (>2 GB) may timeout on upload — see alternative distribution options below

### Build minutes running out (private repo)
- Make the repository public (Settings → Danger Zone → Change visibility)
- Or upgrade to GitHub Pro ($4/month) for 3,000 minutes

---

## If the ISO Is Too Large for GitHub Releases (>2 GB)

Three options, all free:

**Option 1: Cloudflare R2** (best)
- Free for up to 10 GB/month
- I can add an upload step to the workflow

**Option 2: Internet Archive**
- `archive.org` allows large free file hosting
- Public, permanent links

**Option 3: Split the ISO**
- Split with `split -b 1900m CanveraOS.iso CanveraOS.iso.part`
- Users reassemble with `cat CanveraOS.iso.part* > CanveraOS.iso`
- Both parts fit in GitHub Releases

Tell me which option you prefer and I'll implement it.
