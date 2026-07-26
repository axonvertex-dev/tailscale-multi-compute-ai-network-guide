# Publish This Repository to GitHub

This guide publishes the local repository to the GitHub account `axonvertex-dev` over HTTPS using a GitHub Personal Access Token (PAT).

## Recommended repository identity

Repository name:

```text
tailscale-multi-compute-ai-network-guide
```

Full GitHub repository path:

```text
axonvertex-dev/tailscale-multi-compute-ai-network-guide
```

Recommended description:

```text
Instructional guide and reference implementation for connecting Linux, macOS, and Windows/WSL compute nodes over Tailscale with SSH access and private AI model routing.
```

Start with the repository set to **Private**. The guide contains real example machine names, private Tailscale addresses, and an identity handle. These are not public credentials, but they are operational metadata. Review or anonymize them before changing the repository to Public.

## Important authentication rule

GitHub no longer accepts an account password for Git operations over HTTPS. At the password prompt, paste the Personal Access Token instead.

Do not permanently place a token inside the remote URL, for example:

```text
https://USERNAME:TOKEN@github.com/OWNER/REPOSITORY.git
```

That form can expose the token through shell history, logs, configuration files, screenshots, and process inspection.

## Step 1: Extract the ZIP archive

On macOS, assuming the ZIP is in `~/Downloads`:

```bash
cd ~/Downloads
unzip tailscale-multi-compute-ai-network-guide.zip
cd tailscale-multi-compute-ai-network-guide
```

Confirm the repository contents:

```bash
pwd
find . -maxdepth 3 -type f | sort
```

Expected root files include:

```text
.gitignore
LICENSE
Makefile
README.md
SECURITY.md
config/
docs/
router/
scripts/
```

## Step 2: Check that no secrets are present

Never commit Tailscale auth keys, GitHub tokens, API keys, `.env` files, private SSH keys, or production model credentials.

Run these checks before initializing Git:

```bash
grep -RInE --exclude-dir=.git 'tskey-|github_pat_|ghp_|AKIA|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY' . || true
find . -type f \( -name '.env' -o -name '*.pem' -o -name '*.key' \) -print
```

The supplied `.gitignore` already excludes `.env`, generated logs, local model configuration, cache files, and IDE metadata.

## Step 3: Configure the Git commit identity

Check the current values:

```bash
git config --global user.name
git config --global user.email
```

Set them if required:

```bash
git config --global user.name "Krishnendu Dasgupta"
git config --global user.email "axonvertex@gmail.com"
```

These values identify the author of Git commits. They are separate from the username used to authenticate to GitHub.

## Step 4: Initialize the local Git repository

From inside `tailscale-multi-compute-ai-network-guide`:

```bash
git init -b main
git status
```

Stage every repository file:

```bash
git add .
git status
```

Create the first commit:

```bash
git commit -m "Initial release: Tailscale multi-compute AI network guide"
```

Verify the commit:

```bash
git log --oneline --decorate -n 3
```

## Step 5: Create an empty GitHub repository

1. Sign in to GitHub as `axonvertex-dev`.
2. Open **New repository**.
3. Set **Owner** to `axonvertex-dev`.
4. Set **Repository name** to `tailscale-multi-compute-ai-network-guide`.
5. Add the recommended description.
6. Select **Private** initially.
7. Do not add a README, `.gitignore`, or license from GitHub. Those files already exist locally.
8. Create the repository.

The resulting remote URL should be:

```text
https://github.com/axonvertex-dev/tailscale-multi-compute-ai-network-guide.git
```

## Step 6: Create a fine-grained Personal Access Token

Create the repository before creating the token so that the token can be restricted to this repository.

In GitHub:

1. Open your profile menu and select **Settings**.
2. Open **Developer settings**.
3. Open **Personal access tokens**.
4. Select **Fine-grained tokens**.
5. Select **Generate new token**.
6. Give it a descriptive name such as:

   ```text
   macbook-tailscale-guide-push
   ```

7. Set an expiration date. A finite duration such as 30 or 90 days is safer than an unlimited token.
8. Set **Resource owner** to `axonvertex-dev`.
9. Under **Repository access**, select **Only select repositories**.
10. Select `tailscale-multi-compute-ai-network-guide`.
11. Under **Repository permissions**, set:

    ```text
    Contents: Read and write
    Metadata: Read-only
    ```

12. Generate the token.
13. Copy it immediately and store it in a password manager. GitHub will not show the full token again.

Never place the token in this repository, a Markdown file, a screenshot, a chat message, or a shell script.

## Step 7: Configure secure credential storage on macOS

Confirm that the macOS Keychain credential helper is available:

```bash
git credential-osxkeychain
```

If it prints usage information, enable it:

```bash
git config --global credential.helper osxkeychain
```

Confirm:

```bash
git config --global --get credential.helper
```

Expected output:

```text
osxkeychain
```

This allows Git to store the HTTPS credential in macOS Keychain rather than embedding the token in the repository URL.

## Step 8: Add the GitHub remote

Add the remote without a token:

```bash
git remote add origin https://github.com/axonvertex-dev/tailscale-multi-compute-ai-network-guide.git
```

Verify it:

```bash
git remote -v
```

Expected output:

```text
origin  https://github.com/axonvertex-dev/tailscale-multi-compute-ai-network-guide.git (fetch)
origin  https://github.com/axonvertex-dev/tailscale-multi-compute-ai-network-guide.git (push)
```

The output must not contain a PAT.

## Step 9: Push the repository

Push the `main` branch:

```bash
git push -u origin main
```

When Git prompts for credentials, enter:

```text
Username: axonvertex-dev
Password: paste the Personal Access Token
```

The terminal normally does not display characters while the token is pasted. Press Enter once after pasting it.

The `-u` option records `origin/main` as the upstream branch. Later pushes require only:

```bash
git push
```

## Step 10: Verify GitHub and the remote state

Open the repository in GitHub and confirm that the following are visible:

```text
README.md
SECURITY.md
LICENSE
config/
docs/
router/
scripts/
```

Verify locally:

```bash
git status
git branch -vv
git remote -v
```

Expected status:

```text
On branch main
Your branch is up to date with 'origin/main'.
nothing to commit, working tree clean
```

## Normal update workflow

After editing repository files:

```bash
cd ~/Downloads/tailscale-multi-compute-ai-network-guide

git status
git diff

git add .
git commit -m "Document model routing and node onboarding"
git push
```

Before each commit, inspect the staged changes:

```bash
git diff --cached
```

## Optional: Push using GitHub CLI

GitHub CLI can manage HTTPS authentication and repository creation.

Install it on macOS:

```bash
brew install gh
```

Authenticate:

```bash
gh auth login
```

Choose:

```text
GitHub.com
HTTPS
Authenticate Git with your GitHub credentials: Yes
```

After authentication, an existing local repository can be created and pushed with:

```bash
gh repo create axonvertex-dev/tailscale-multi-compute-ai-network-guide \
  --private \
  --source=. \
  --remote=origin \
  --push
```

Use this command only when the remote GitHub repository has not already been created.

## Do not use these unsafe patterns

Do not export the token into a reusable shell profile:

```bash
export GITHUB_TOKEN=github_pat_actual_token_here
```

Do not put it in the remote URL:

```bash
git remote add origin https://axonvertex-dev:github_pat_actual_token_here@github.com/axonvertex-dev/tailscale-multi-compute-ai-network-guide.git
```

Do not commit it in a file:

```text
TOKEN=github_pat_actual_token_here
```

Do not use Git's plaintext credential store:

```bash
git config --global credential.helper store
```

On macOS, use `osxkeychain`, GitHub CLI, or Git Credential Manager instead.

## If a token was accidentally exposed

1. Revoke the token immediately in GitHub settings.
2. Generate a replacement with the minimum required repository access.
3. Remove the token from the Git remote if it was embedded there:

   ```bash
   git remote set-url origin https://github.com/axonvertex-dev/tailscale-multi-compute-ai-network-guide.git
   ```

4. Remove it from shell history where supported:

   ```bash
   history
   history -d HISTORY_LINE_NUMBER
   ```

5. If it was committed, rotate the token before attempting history cleanup. Deleting a line in a later commit does not remove it from earlier Git history.

## Optional public-release preparation

Before making the repository public, consider replacing:

```text
rentorzos-macbook-pro-2
axonvertex-01
axonvertex-personal-01
krishdasgupta.official@
100.76.212.84
100.82.103.57
100.99.149.21
```

with neutral example identities and addresses, or explicitly retain them as a documented reference deployment after reviewing the exposure.

Run a final check:

```bash
git grep -nE 'tskey-|github_pat_|ghp_|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY' -- . || true
git status
git log --oneline --decorate -n 10
```

## Official GitHub references

- Creating a repository: https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository
- Adding locally hosted code: https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github
- Managing Personal Access Tokens: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
- Authentication overview: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-authentication-to-github
