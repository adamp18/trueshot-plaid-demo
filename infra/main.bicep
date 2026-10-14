targetScope = 'resourceGroup'

metadata description = 'One Free-tier Static Web App for the True Shot sales demo. No repository link, no Key Vault, no role assignments, and no deployment-token output.'

// Static Web Apps is offered in centralus, eastus2, eastasia, westeurope, and westus2.
// eastus2 is on that list, so the requested region is used as-is.
@description('Static Web Apps region. eastus2 is supported for this resource type.')
@allowed([
  'eastus2'
  'centralus'
  'westus2'
  'westeurope'
  'eastasia'
])
param location string = 'eastus2'

// Fixed name so a parameter override cannot publish a different site.
var staticSiteName = 'swa-dmp-trueshot-demo'

resource staticSite 'Microsoft.Web/staticSites@2025-03-01' = {
  name: staticSiteName
  location: location
  tags: {
    owner: 'adam'
    purpose: 'trueshot-demo'
  }
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    // Honor site/staticwebapp.config.json on deploy (noindex and the other headers).
    allowConfigFileUpdates: true
    // One public production URL. Preview environments are not part of this demo.
    stagingEnvironmentPolicy: 'Disabled'
    // repositoryUrl, branch, and repositoryToken are omitted on purpose.
    // Content is uploaded later with the deployment token, not by linking this repo.
  }
}

@description('Public hostname of the Static Web App.')
output defaultHostname string = staticSite.properties.defaultHostname

@description('Resource id of the Static Web App.')
output staticSiteId string = staticSite.id
