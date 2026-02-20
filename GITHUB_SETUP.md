# Getting Started with GitHub — For First-Timers

This guide is written for someone who has never used GitHub before and does not yet have an account.
Follow these steps in order. Each step is small and explains what you're doing and why.

> 💡 **Stuck at any point?** Copy the step you're on and paste it into [ChatGPT](https://chatgpt.com) and ask "help me do this step." It will walk you through it.

---

## Step 1 — Create a GitHub Account

GitHub is a website where developers store and share code. You need a free account to get a copy of this project.

1. Go to **[https://github.com](https://github.com)**
2. Click **"Sign up"** in the top-right corner
3. Enter your email address, create a password, and pick a username
   - Your username will be visible publicly — pick something professional (e.g., `jsmith-dev`)
4. Verify your email address — GitHub will send you a confirmation link
5. On the plan selection screen, choose **Free**

**You now have a GitHub account.**

---

## Step 2 — Fork the SongVault Repository

"Forking" means making your own personal copy of someone else's project. You need your own copy so you can work on it independently.

1. Go to the SongVault project page:
   **[https://github.com/WGLewis0721/Songvault-ksb-](https://github.com/WGLewis0721/Songvault-ksb-)**
2. In the top-right corner of the page, click the **"Fork"** button
3. On the next screen, leave everything as-is and click **"Create fork"**

GitHub will create a copy of the project under your own account. The URL will change to:
```
https://github.com/YOUR_USERNAME/Songvault-ksb-
```

**You now have your own copy of SongVault.**

---

## Step 3 — Install Git on Your Computer

Git is a tool that lets you download code from GitHub onto your computer and track changes. This is separate from the GitHub website.

**Check if Git is already installed** — open a terminal (Mac: Terminal app; Windows: Git Bash or PowerShell) and run:
```bash
git --version
```

If you see something like `git version 2.x.x`, Git is already installed. Skip to Step 4.

**If Git is not installed:**

- **Mac:** Run `brew install git` (requires [Homebrew](https://brew.sh)) or download from [https://git-scm.com/download/mac](https://git-scm.com/download/mac)
- **Windows:** Download from [https://git-scm.com/download/win](https://git-scm.com/download/win) and run the installer
- **Linux (Ubuntu/Debian):** Run `sudo apt-get install git -y`

Verify after installing:
```bash
git --version
```

> 💡 **Stuck?** Ask ChatGPT: *"How do I install Git on [your operating system]?"*

---

## Step 4 — Tell Git Who You Are

Git needs your name and email to track your work. This only needs to be done once.

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

Use the same email you used to sign up for GitHub.

---

## Step 5 — Clone the Repository to Your Computer

"Cloning" means downloading the code from GitHub to your local machine so you can work with it.

1. Go to your forked repository on GitHub:
   `https://github.com/YOUR_USERNAME/Songvault-ksb-`
2. Click the green **"Code"** button
3. Make sure **HTTPS** is selected (not SSH)
4. Copy the URL shown (it will look like `https://github.com/YOUR_USERNAME/Songvault-ksb-.git`)
5. In your terminal, run:

```bash
git clone https://github.com/YOUR_USERNAME/Songvault-ksb-.git
cd Songvault-ksb-
```

Replace `YOUR_USERNAME` with your actual GitHub username.

**You now have the project files on your computer.**

To confirm it worked, list the files:
```bash
ls
```

You should see files including `README.md`, `WALKTHROUGH.md`, `terraform/`, and `app/`.

> 💡 **Stuck?** Ask ChatGPT: *"How do I clone a GitHub repository using HTTPS?"*

---

## Step 6 — You're Ready

You now have:
- ✅ A GitHub account
- ✅ Your own fork of SongVault
- ✅ Git installed on your computer
- ✅ The project cloned locally

**Next step:** Follow [WALKTHROUGH.md](WALKTHROUGH.md) to deploy the application to AWS.

Start at **Phase 1 — Install the Tools** in the walkthrough. The walkthrough explains every command with expected output and common errors.

---

## Quick Reference — What These Words Mean

| Term | What it means |
|------|---------------|
| **Repository (repo)** | A folder of code stored on GitHub |
| **Fork** | Your personal copy of someone else's repo |
| **Clone** | Download a repo from GitHub to your computer |
| **Commit** | A saved snapshot of your changes |
| **Push** | Upload your local changes back to GitHub |
| **Terminal** | The command-line application on your computer (Mac: Terminal; Windows: Git Bash) |

---

> 💡 **General tip when stuck:** Open [ChatGPT](https://chatgpt.com) and describe exactly what step you're on and what error message you see. Example prompt:
> *"I'm trying to clone a GitHub repo. I ran `git clone ...` and got this error: [paste the error]. What does this mean and how do I fix it?"*
