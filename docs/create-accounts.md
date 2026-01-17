# Create Your Accounts

Before you can use lab compute resources, you need to create accounts and submit your information to the lab.

## Overview

You'll need to:

1. Create a GitHub account
2. Create an FASRC account
3. Submit your info to George
4. Wait for AWS credentials setup

## 1. Create a GitHub Account

If you don't already have one, create a GitHub account:

1. Go to https://github.com
2. Click "Sign up"
3. Follow the prompts to create your account

**Note your GitHub username** (e.g., `@yourusername`) — you'll need this for the lab info form.

## 2. Create an FASRC Account

Request an account on the Harvard FASRC cluster:

1. Go to https://portal.rc.fas.harvard.edu/request/account/new
2. Complete the account request form
3. Wait for approval (typically 1-2 business days)

**Official quickstart guide:** https://docs.rc.fas.harvard.edu/kb/quickstart-guide/

### Set Your FASRC Password

Once your account is approved, set your password:

1. Go to https://portal.rc.fas.harvard.edu/p3/pwreset/
2. Set a strong password

> **Note:** This is separate from your Harvard password. You'll use this password for VPN and SSH access.

## 3. Submit Your Info to George

Once you have your accounts, Slack George (`@grez72`) with the following information:

| Info | Where to find it | Example |
|------|------------------|---------|
| **GitHub username** | Your GitHub profile | `@yourusername` |
| **GitHub email** | GitHub Settings > Emails | `you@example.com` |
| **FASRC username** | Account approval email, or run `echo $USER` on the cluster | `yourusername` |

This information will be used to:
- Add you to the [harvard-visionlab](https://github.com/harvard-visionlab) GitHub organization
- Set up your AWS credentials for S3 access
- Configure your lab storage allocations

## 4. Wait for AWS Credentials

George will set up your AWS credentials and let you know when they're ready. You'll receive:

- AWS Access Key ID
- AWS Secret Access Key

Keep these secure. You'll configure them during the [laptop setup](laptop-macos.md) and [cluster setup](harvard-cluster.md).
