// dev.bicepparam — parameter values for the dev environment
// Used by both subscription.bicep and main.bicep
// DO NOT commit real subscription IDs or secrets to source control

using '../main.bicep'

param project = 'infraapp'
param environment = 'dev'
param location = 'canadacentral'
param authorizedIpRange = '0.0.0.0/0' // Tighten to your public IP/32 for security
param clusterAdminObjectId = '86cd7a4f-c7f9-4b69-ba37-26f42111c64d'
