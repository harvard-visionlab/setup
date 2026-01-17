# Terminal & SSH Setup

This guide covers advanced SSH configuration for easier cluster access. These steps are optional but recommended for frequent terminal users.

**Official docs:** https://docs.rc.fas.harvard.edu/kb/terminal-access/

## Basic SSH Connection

If you just need to connect occasionally:

```bash
ssh <your-username>@holylogin.rc.fas.harvard.edu
```

Enter your FASRC password and 2FA code when prompted.

> **Note:** Login nodes are for light tasks only (launching jobs, quick file operations). Don't run heavy computations here.

## SSH Config Setup

Create an SSH config file to simplify connections.

### 1. Create the config file

```bash
mkdir -p ~/.ssh
nano ~/.ssh/config
```

### 2. Add host configurations

Add the following, replacing `<your-username>` with your FASRC username:

```
Host holylogin
  HostName holylogin.rc.fas.harvard.edu
  User <your-username>
  Port 22
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes
  AddKeysToAgent yes
  UseKeychain yes
  ControlMaster auto
  ControlPath ~/.ssh/%r@%h:%p

Host holylogin05
  HostName holylogin05.rc.fas.harvard.edu
  User <your-username>
  Port 22
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes
  AddKeysToAgent yes
  UseKeychain yes
  ControlMaster auto
  ControlPath ~/.ssh/%r@%h:%p
```

Save and exit (in nano: `Ctrl+O`, `Enter`, `Ctrl+X`).

## SSH Key Setup

SSH keys let you authenticate without typing your password every time.

### 1. Check for existing keys

```bash
ls -la ~/.ssh/id_rsa*
```

If you see `id_rsa` and `id_rsa.pub`, you already have keys. Skip to step 3.

### 2. Generate a new key pair

```bash
ssh-keygen -t rsa -b 4096
```

Press Enter to accept defaults. This creates:
- `~/.ssh/id_rsa` - Private key (never share this)
- `~/.ssh/id_rsa.pub` - Public key (goes on the cluster)

### 3. Copy your public key to the cluster

```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub <your-username>@holylogin.rc.fas.harvard.edu
```

Enter your password and 2FA code when prompted.

### 4. Test the shortcut

Now you can use the shortcuts defined in your config:

```bash
# System chooses which login node
ssh holylogin

# Force a specific node
ssh holylogin05
```

You'll still need to enter your password and 2FA, but the connection is simpler.

## Background Connection (Avoid Repeated 2FA)

Set up a background SSH connection that stays alive, so subsequent connections don't require re-authentication.

### 1. Add alias to your shell config

Add this to your `~/.zshrc` (or `~/.bashrc`):

```bash
alias holylogin05_background='ssh -CX -o ServerAliveInterval=30 -fN holylogin05'
```

### 2. Reload your shell config

```bash
source ~/.zshrc  # or source ~/.bashrc
```

### 3. Start the background connection

```bash
holylogin05_background
```

Enter your password and 2FA code. The command will return immediately (the connection runs in the background).

### 4. Connect without re-authenticating

Now any `ssh holylogin05` will connect instantly without prompting for credentials:

```bash
ssh holylogin05
```

> **Note:** The background connection persists until you close your laptop or explicitly kill it. You'll need to run `holylogin05_background` again after a restart.

## VS Code Remote Setup

You can connect VS Code directly to cluster nodes for IDE-based development.

> **Coming soon:** Detailed VS Code Remote setup instructions.

For now, with SSH config in place:
1. Install the "Remote - SSH" extension in VS Code
2. Use `Cmd+Shift+P` > "Remote-SSH: Connect to Host"
3. Select `holylogin05` or your configured host

## Troubleshooting

### "Permission denied (publickey)"

Your SSH key isn't set up correctly:
1. Verify the key exists: `ls ~/.ssh/id_rsa*`
2. Re-copy the public key: `ssh-copy-id -i ~/.ssh/id_rsa.pub <user>@holylogin.rc.fas.harvard.edu`

### "Host key verification failed"

The cluster's host key changed (usually after maintenance):
```bash
ssh-keygen -R holylogin.rc.fas.harvard.edu
ssh-keygen -R holylogin05.rc.fas.harvard.edu
```

Then try connecting again and accept the new key.

### Background connection died

Just run the alias again:
```bash
holylogin05_background
```

### ControlPath socket errors

Remove stale socket files:
```bash
rm -f ~/.ssh/*@*
```

## Summary

After setup, your typical workflow:

```bash
# Start of work session: establish background connection
holylogin05_background

# Connect as many times as needed (no re-auth)
ssh holylogin05

# Or use VS Code Remote to connect directly
```
