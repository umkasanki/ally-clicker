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

**2. Install.** Double-click the downloaded file. A window opens showing two
things side by side: the AllyClicker application on the left, and a shortcut to
your Applications folder on the right. Drag the application onto that folder and
let go. The copy takes a second or two.

Then close the window and eject the disk image — it appears in the Finder
sidebar under *Locations* with an eject symbol next to it. The application now
lives in Applications and the image is no longer needed.

**3. Try to open it — and expect to be refused.** Open your Applications folder
and double-click AllyClicker.

A dialog appears saying that macOS **cannot verify that the application is free
of malware**, and suggesting that you move it to the Bin. It does not offer to
open it: on current macOS the buttons are only *Move to Bin* and *Done*
(in Russian, «Переместить в Корзину» and «Готово»).

**Press Done.** Do not move it to the Bin. Nothing is wrong with the
application — macOS is saying that it has not been given Apple's blessing, which
costs money this project has not spent. The next step tells macOS to allow it
anyway.

**4. Allow it.** Open **System Settings** (the gear icon in the Dock, or the
Apple menu → System Settings), choose **Privacy & Security** in the sidebar —
it is roughly two thirds of the way down the list — and scroll the right-hand
pane almost to the bottom, past App Management and Full Disk Access, to the
section headed **Security**.

There you will find a line of text saying that *"AllyClicker" was blocked to
protect your Mac*, and beside it a button **Open Anyway**
(«Всё равно открыть»). The line only appears for about an hour after the
refusal; if it is not there, go back and double-click the application once more,
then return.

Press **Open Anyway**. macOS asks for your account password or Touch ID — the
same one you log in with — and then asks once more whether you are sure, with a
button **Open**. Confirm.

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

1. Open **System Settings → Privacy & Security**, and in the right-hand pane
   choose **Accessibility** (it is near the top of that pane, under the heading
   of the same name).
2. A list of applications appears, each with a switch. Find **AllyClicker** and
   turn its switch on. macOS asks for your password or Touch ID.
3. If AllyClicker is not in the list at all, press the **+** button underneath
   it, find AllyClicker in your Applications folder, choose **Open**, and then
   turn on the switch that appears.
4. **Quit AllyClicker and start it again.** This step is easy to miss and
   nothing works without it: the application reads its permissions once, when it
   starts, so a permission granted to a running application has no effect until
   the next launch.

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
