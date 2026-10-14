# True Shot wholesale checkout demo

Static sales demo for Dynamic Merchant Processing. The page is sample data only: a simulated Plaid Link window and a simulated Titanium Flex checkout for True Shot. There is no backend. The only external request the page makes is for Google Fonts.

The site is published as the contents of `site/` to one Azure Static Web App on the Free SKU. The resource is not linked to this repository. A human deploys the template, stores the deployment token as a GitHub Actions secret, and the workflow uploads `site/`.

## Region

`eastus2` is a supported Static Web Apps region, so the template uses it. Static Web Apps is offered in `centralus`, `eastus2`, `eastasia`, `westeurope`, and `westus2`. The parameter allow-list is those five regions.

## Files

| Path | Purpose |
| --- | --- |
| `site/index.html` | Self-contained demo. Published unchanged. |
| `site/staticwebapp.config.json` | Sends `X-Robots-Tag: noindex, nofollow`, `X-Content-Type-Options: nosniff`, and `Referrer-Policy: no-referrer`. |
| `site/robots.txt` | Disallows all crawlers. |
| `infra/main.bicep` | One `Microsoft.Web/staticSites` resource. |
| `infra/main.bicepparam` | Pins the location to `eastus2`. |
| `.github/workflows/deploy.yml` | Uploads `site/` with the pinned Azure Static Web Apps deploy action. |

The Bicep template does not create a Key Vault, a role assignment, or any other resource. It does not call `listSecrets` and it does not output the deployment token. Outputs are the public hostname and the resource id.

## Run this yourself

You need Azure CLI signed in to the subscription that should own `rg-dmp-trueshot-demo`, and GitHub CLI authenticated with permission to set Actions secrets on `adamp18/trueshot-plaid-demo`. Run the GitHub commands from a clone of this repository.

Do not print the deployment token. Do not commit it, paste it into a ticket, or write it to a file in the repo. Run the token commands with shell tracing off (`set +x`).

### 1. Create the resource group

```bash
az group create \
  --name rg-dmp-trueshot-demo \
  --location eastus2 \
  --tags owner=adam purpose=trueshot-demo
```

### 2. Deploy the Bicep

```bash
az deployment group create \
  --name swa-dmp-trueshot-demo \
  --resource-group rg-dmp-trueshot-demo \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam
```

The deployment output includes `defaultHostname`. It does not include the deployment token. If the name `swa-dmp-trueshot-demo` is already taken, stop and tell Adam. Do not rename the site in the template as part of a retry.

### 3. Fetch the deployment token into a variable without printing it

```bash
set +x
AZURE_STATIC_WEB_APPS_API_TOKEN="$(
  az staticwebapp secrets list \
    --name swa-dmp-trueshot-demo \
    --resource-group rg-dmp-trueshot-demo \
    --query properties.apiKey \
    --output tsv
)"
if [ -z "${AZURE_STATIC_WEB_APPS_API_TOKEN}" ]; then
  echo "Deployment token was empty. Stop."
  exit 1
fi
echo "Deployment token is set (${#AZURE_STATIC_WEB_APPS_API_TOKEN} characters). Value not printed."
```

`az staticwebapp secrets list` prints the token when its output is not captured. Keep the command substitution.

### 4. Set the repository secret

```bash
printf '%s' "${AZURE_STATIC_WEB_APPS_API_TOKEN}" | gh secret set AZURE_STATIC_WEB_APPS_API_TOKEN
unset AZURE_STATIC_WEB_APPS_API_TOKEN
```

`gh secret set` reads the value from stdin, so the token is not a process argument. Confirm with `gh secret list`. That command shows the secret name, not the value.

### 5. Trigger the workflow

After this change is on `main`:

```bash
gh workflow run deploy.yml --ref main
gh run watch "$(gh run list --workflow deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
```

The workflow runs on a push to `main` that changes `site/**`, and when someone starts it with `workflow_dispatch`. The deploy job runs only for `refs/heads/main`, so a manual run of another branch does not publish. It uploads `site/` with `skip_app_build: true` and reads only the secret `AZURE_STATIC_WEB_APPS_API_TOKEN`.

Wait until the run succeeds before the curl check. The hostname answers before the first upload, and that answer is not the demo yet.

### 6. Verify

```bash
HOSTNAME="$(
  az staticwebapp show \
    --name swa-dmp-trueshot-demo \
    --resource-group rg-dmp-trueshot-demo \
    --query defaultHostname \
    --output tsv
)"
curl -I "https://${HOSTNAME}/"
```

Expect status `200` and the header `X-Robots-Tag: noindex, nofollow`. Azure may send the header name in lowercase. The same response should also include `X-Content-Type-Options: nosniff` and `Referrer-Policy: no-referrer`.

### 7. Tear down

```bash
az group delete --name rg-dmp-trueshot-demo --yes
gh secret delete AZURE_STATIC_WEB_APPS_API_TOKEN
```

Deleting the resource group deletes the Static Web App. Deleting the Actions secret removes the deployment token from the repository.
