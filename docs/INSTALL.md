# Installing AllyClicker

There are two ways. **Homebrew is the one to use** — it installs the app and
nothing stands in your way. The `.dmg` works too, but macOS will refuse to open
the app once, and you will have to tell it to allow it.

If you only want the short version, it is at the top of the
[README](../README.md). This page is for when something asks a question you
did not expect.

---

## Why there are two ways, and why one of them is awkward

AllyClicker is signed with a certificate I made myself, not one issued by Apple.
Apple's is part of a paid developer membership, and this is a free application
given away to a handful of people, so it has not been bought.

macOS treats anything downloaded from the internet that Apple has not vouched
for as suspect: it attaches an invisible "quarantine" mark to the file, and
refuses to launch it. The mark is attached by whatever downloads the file.

**Homebrew removes that mark for you as part of installing.** A web browser does
not, and nothing inside the downloaded file can remove it either. That is the
whole of the difference between the two methods.

---

## Method 1 — Homebrew (recommended)

### What Homebrew is

A package manager for macOS: a program that installs other programs. One command
installs an application, another updates it, a third removes it cleanly. It is
free, widely used, and installs into its own folder without touching the system.

### If you do not have it yet

Open **Terminal** (⌘Space, type `Terminal`, Enter) and paste this single line,
which comes from [brew.sh](https://brew.sh):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

It will ask for your account password — the same one you log in with — and may
install Apple's Command Line Tools first, which takes a few minutes. When it
finishes it prints two or three commands of its own to run; run them, or
Homebrew will not be found afterwards.

### Install AllyClicker

```bash
brew tap umkasanki/tap
brew trust umkasanki/tap
brew install --cask allyclicker
```

The first line adds my collection of applications. The second says you trust it:
Homebrew asks this once for any collection that is not its own. Adding a *new*
application from the same collection later asks again — that is normal, not a
sign that something went wrong.

The third installs AllyClicker into your Applications folder and clears the
quarantine mark on the way, so the app opens the first time without argument.

Then give it permission to click: **[Granting Accessibility](#granting-accessibility)**.

### Updating and removing

```bash
brew upgrade --cask allyclicker     # update to the newest release
brew uninstall --cask allyclicker   # remove the application
brew uninstall --zap --cask allyclicker   # remove it and its settings
```

---

## Method 2 — the `.dmg` file

### What a `.dmg` is

A disk image: a single file that behaves like a disc. You double-click it, a
window opens with the application inside, and you drag that application into
your Applications folder. It is the ordinary way macOS software is handed out.

### Why this is the second choice here

Because of the quarantine mark described above. A browser attaches it, and
macOS will stop the first launch. You can get past it — the steps are below and
they are not hard — but it is three or four extra actions, and one of them has
to be done in System Settings.

If you can use Homebrew, use Homebrew. If you cannot, or do not want to, this
way works and the result is exactly the same application.

### Steps

**1. Download.** Open the [latest release](https://github.com/umkasanki/ally-clicker/releases/latest)
and download `AllyClicker-<version>.dmg`.

**2. Install.** Double-click the downloaded file. A window opens with
AllyClicker in it. Drag AllyClicker onto the Applications folder shown beside
it.

![The disk image window, with the app being dragged to Applications](images/install-dmg-drag.png)

**3. Try to open it — and expect to be refused.** Open your Applications folder
and double-click AllyClicker. macOS will show a dialog saying it cannot verify
that the app is free of malware. This is expected. Click **Done** (there is no
"Open" button in it on current macOS).

![macOS refusing the first launch](images/install-blocked.png)

**4. Allow it.** Open **System Settings → Privacy & Security**, scroll down to
the **Security** section. There is a line saying AllyClicker was blocked, with
a button **Open Anyway**. Press it, and confirm with your password or Touch ID.

![The Open Anyway button in Privacy and Security](images/install-open-anyway.png)

**5. Open the app again.** It starts normally, and will keep starting normally
from now on.

> **Do not bother with "right-click → Open".** Older guides — including an
> earlier version of this one — say that holding Control and choosing Open gets
> past the block. On current macOS it does not; the app is refused anyway.

### If you are comfortable with Terminal

One command does what steps 3–5 do, before you ever launch the app:

```bash
xattr -dr com.apple.quarantine /Applications/AllyClicker.app
```

### Updating and removing

To update, download the newer `.dmg` and drag the new app over the old one,
replacing it. The permission you granted is kept, because it is tied to the
signing certificate rather than to that particular copy of the file.

To remove, drag AllyClicker from Applications to the Trash. Its settings live in
`~/Library/Preferences/com.allyclicker.app.plist` if you want those gone too.

---

## Granting Accessibility

AllyClicker clicks for you, and macOS does not let an application click on
behalf of a person unless you say so explicitly.

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Find **AllyClicker** in the list and switch it on.
3. If it is not in the list, press **+**, choose AllyClicker in Applications,
   then switch it on.
4. Quit AllyClicker and start it again. Permissions are read at launch.

![AllyClicker enabled in the Accessibility list](images/install-accessibility.png)

Without this the panel appears and the dwell highlight works, but nothing is
ever clicked.

---

## When something is still wrong

**"AllyClicker is damaged and can't be opened."** The same quarantine mark,
phrased differently by macOS. Step 4 above fixes it, or the Terminal command.

**The panel appears but nothing clicks.** Accessibility permission is missing or
was lost. Check the list above; if AllyClicker is in it and switched on, switch
it off and on again, then restart the app.

**It worked, then stopped after an update.** Check Accessibility first. If the
entry is gone from the list entirely, add it again with **+**.

**You cannot click well enough to do any of this.** macOS has its own dwell
clicking built in, and it works before anything is installed: **System Settings
→ Accessibility → Pointer Control → Alternative Control Methods**. Turn on head
pointer or dwell there, use it to get through the steps above, and turn it off
afterwards if you prefer AllyClicker.

---

## Operating the login screen

AllyClicker runs as part of your session and cannot appear on the macOS login
window. To type your password hands-free there, use the features that do run
before login: **Pointer Control → Dwell** and the **Accessibility Keyboard**,
both in System Settings → Accessibility.
