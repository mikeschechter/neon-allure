# Neon Allure

Las Vegas events, entertainment, nightlife, and news — powered by [Hugo](https://gohugo.io/) and hosted on [Azure Static Web Apps](https://azure.microsoft.com/en-us/products/app-service/static).

## Local Development

```bash
# Install Hugo (macOS)
brew install hugo

# Run dev server
hugo server -D

# Build for production
hugo --minify
```

## Deployment

This site auto-deploys to Azure Static Web Apps via GitHub Actions on push to `main`.

### Setup Steps

1. **Create a GitHub repo** and push this code
2. **Create an Azure Static Web App** in the [Azure Portal](https://portal.azure.com):
   - Go to **Create a resource** → **Static Web App**
   - Choose your subscription and resource group
   - Name: `neon-allure`
   - Plan: Free
   - Source: GitHub → connect your repo
   - Build preset: **Custom**
   - App location: `public`
   - Skip the API and output locations
3. **Copy the deployment token** from Azure and add it as a GitHub secret:
   - Go to your Azure Static Web App → **Manage deployment token**
   - In GitHub: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**
   - Name: `AZURE_STATIC_WEB_APPS_API_TOKEN`
   - Value: paste the token
4. **Push to `main`** — GitHub Actions will build and deploy automatically

### Custom Domain

In Azure Portal → your Static Web App → **Custom domains** → Add your domain.

## Writing Posts

Create new posts in `content/posts/`:

```bash
hugo new content posts/my-new-post.md
```

Posts use front matter for metadata:

```yaml
---
title: "Your Post Title"
date: 2026-02-08
draft: false
summary: "A brief description"
categories: ["Events"]
tags: ["tag1", "tag2"]
---
```

## Categories

- **Events** — Festivals, conventions, sporting events
- **Nightlife** — Clubs, bars, lounges
- **Shows** — Residencies, performances, comedy
- **News** — Development, business, community updates
