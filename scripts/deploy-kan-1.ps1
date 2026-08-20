# Deployment script for KAN-1: Create new fields on Account Object
# This script deploys the custom fields to a Salesforce org
# Usage: .\deploy-kan-1.ps1

Write-Host "==================================" -ForegroundColor Green
Write-Host "Deploying KAN-1 User Story" -ForegroundColor Green
Write-Host "Adding custom fields to Account object" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green
Write-Host ""

# Deploy metadata using SFDX CLI
Write-Host "Deploying Account custom fields..." -ForegroundColor Cyan
sf project deploy start --source-dir force-app/main/default/objects/Account/

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Custom fields created:" -ForegroundColor Yellow
    Write-Host "  1. Account_Summary__c (Long Text Area)" -ForegroundColor Yellow
    Write-Host "     - Max length: 131,072 characters" -ForegroundColor Gray
    Write-Host "     - Display lines: 5" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Account_Budget__c (Currency)" -ForegroundColor Yellow
    Write-Host "     - Precision: 18 digits" -ForegroundColor Gray
    Write-Host "     - Scale: 2 decimal places" -ForegroundColor Gray
    Write-Host ""
    Write-Host "These fields can now be used in:" -ForegroundColor Cyan
    Write-Host "  - Flows" -ForegroundColor Gray
    Write-Host "  - Apex code" -ForegroundColor Gray
    Write-Host "  - Page layouts" -ForegroundColor Gray
    Write-Host "  - Reports and Dashboards" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    Write-Host "Please check the error messages above" -ForegroundColor Red
    exit 1
}
