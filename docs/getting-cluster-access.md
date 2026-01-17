# Getting Cluster Access

This guide walks you through setting up VPN, two-factor authentication, and verifying your cluster access.

> **Prerequisite:** You must have an FASRC account. See [Create Your Accounts](create-accounts.md) first.

## Overview

You'll need to:

1. Enable two-factor authentication (2FA)
2. Install VPN software
3. Verify SSH access
4. Test interactive access (optional)

## 1. Enable Two-Factor Authentication

Set up Duo Mobile for 2FA:

1. Open Duo Mobile on your phone
2. Add a new service/account
3. Scan the QR code from the FASRC setup page

**Reference:** https://docs.rc.fas.harvard.edu/kb/duo-mobile/

> **Note:** The official instructions can be a bit circular. The key steps are: add a new service in Duo Mobile, then scan the QR code displayed on the FASRC website.

## 2. Install VPN Software

You must be connected to the VPN to access the cluster.

### Download Cisco AnyConnect

1. Search for "Harvard VPN" or go to https://vpn.harvard.edu
2. Sign in with your Harvard account
3. Download and install Cisco AnyConnect

> **Note:** You don't need to enable the extra privacy/telemetry options during installation.

### Connect to the VPN

1. Open Cisco AnyConnect
2. Enter the server address:
   ```
   vpn.rc.fas.harvard.edu
   ```
3. Login with your FASRC credentials:
   - **Username:** `yourusername@fasrc` (note the `@fasrc` suffix)
   - **Password:** Your FASRC password
   - **Second authentication:** 6-digit code from Duo Mobile

**Reference:** https://docs.rc.fas.harvard.edu/kb/vpn-setup/

> **Troubleshooting:** If login fails, verify your credentials at https://portal.rc.fas.harvard.edu/

## 3. Verify SSH Access

With the VPN connected, verify you can SSH into the cluster.

Open a terminal and run:

```bash
ssh <your-username>@login.rc.fas.harvard.edu
```

Enter your FASRC password when prompted, then your 2FA code.

> **Important:** This logs you into a shared login node. Don't run heavy computations here—it's only for light tasks and launching jobs.

### Verify Your Username

Once logged in, confirm your username:

```bash
echo $USER
```

This is your `VISLAB_USERNAME` and should match your FASRC username.

### Check Your SLURM Accounts

See which accounts you have access to:

```bash
sacctmgr show assoc user=$USER format=account%30
```

You should see accounts like `kempner_alvarez_lab` or `kempner_konkle_lab`.

## 4. Test Interactive Access (Optional)

Verify you can launch an interactive session:

1. Go to https://rcood.rc.fas.harvard.edu/pun/sys/dashboard
2. Login with:
   - **Username:** Your FASRC username (without `@fasrc`)
   - **Password:** Your FASRC password
3. Under Interactive Apps, click "Jupyter notebook / Jupyterlab"
4. Try launching a session on the `gpu_test` partition

If the session launches successfully, your access is fully configured.
