# Shell Vault Guide

The **Shell Vault** provides a secure, encrypted-at-rest storage for your sensitive environment variables (API Keys, Token, Passwords).

## 🚀 Quick Start

### 1. Enable Secrets
Import your existing `secrets.env` file into the vault.
```bash
vault_load
```
*(This encrypts the file and removes the plaintext source)*

### 2. Add Single Secret
```bash
add_secret GITHUB_TOKEN
# Prompts for value and password securely
```

### 3. Use Secret
In your terminal or script:
```bash
use_secret GITHUB_TOKEN
```
*(Exports `GITHUB_TOKEN` to the current session only)*

## 📖 Command Reference

| Command | Description |
| :--- | :--- |
| **`vault_ls`** | List all keys stored in the vault. |
| **`add_secret [KEY]`** | Encrypt and store a new secret. |
| **`show_secret [KEY]`** | Decrypt and display a secret (requires password). |
| **`use_secret [KEY]`** | Decrypt and export secret to ENV. |
| **`delete_secret [KEY]`** | Permanently remove a secret. |
| **`vault_load`** | Bulk import from `secrets.env`. |

## 🔒 Security Model
- **Storage**: `~/.config/secrets/vault.store`
- **Encryption**: AES-256-CBC (via OpenSSL).
- **Protection**: Secrets are never written to disk in plaintext. Decryption happens in memory.
