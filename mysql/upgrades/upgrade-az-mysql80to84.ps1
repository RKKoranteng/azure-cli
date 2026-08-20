# name : upgrade-az-mysql80to84.ps1 
# auth : Richard Koranteng (richard@rkkoranteng.com)
# desc : upgrade azure flexible server mysql 8.0 to 8.4
#        see documentation in docs/upgrade-az-mysql80to84.md

param (
    [Parameter(
        Mandatory = $true,
        Position = 0,
        HelpMessage = "Path to the CSV file containing Azure MySQL servers."
    )]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Leaf)) {
            throw "Server list file was not found: $_"
        }

        if ([System.IO.Path]::GetExtension($_) -ne ".csv") {
            throw "The server list must be a CSV file."
        }

        return $true
    })]
    [string]$ServerListFile,

    [Parameter(Mandatory = $false)]
    [string]$TargetVersion = "8.4"
)

$ErrorActionPreference = "Stop"
$DefaultGeneralPurposeSku = "Standard_D2ds_v4"

Write-Host ""
Write-Host "Azure MySQL Flexible Server Upgrade"
Write-Host "Server list:    $ServerListFile"
Write-Host "Target version: $TargetVersion"
Write-Host ""

try {
    $Servers = Import-Csv -Path $ServerListFile
}
catch {
    throw "Unable to read server list file '$ServerListFile': $($_.Exception.Message)"
}

if (-not $Servers) {
    throw "The server list file is empty."
}

$RequiredColumns = @(
    "ResourceGroup",
    "ServerName",
    "SKU"
)

$AvailableColumns = $Servers[0].PSObject.Properties.Name

foreach ($Column in $RequiredColumns) {
    if ($Column -notin $AvailableColumns) {
        throw "The CSV file is missing the required '$Column' column."
    }
}

$Results = @()

foreach ($Server in $Servers) {
    $ResourceGroup = "$($Server.ResourceGroup)".Trim()
    $ServerName = "$($Server.ServerName)".Trim()
    $ConfiguredSku = "$($Server.SKU)".Trim()

    $SKU = if ([string]::IsNullOrWhiteSpace($ConfiguredSku)) {
        $DefaultGeneralPurposeSku
    }
    else {
        $ConfiguredSku
    }

    $Result = [ordered]@{
        ServerName    = $ServerName
        ResourceGroup = $ResourceGroup
        StartVersion  = $null
        FinalVersion  = $null
        FinalTier     = $null
        FinalSKU      = $null
        Status        = "Failed"
        Message       = $null
    }

    try {
        if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
            throw "ResourceGroup cannot be empty."
        }

        if ([string]::IsNullOrWhiteSpace($ServerName)) {
            throw "ServerName cannot be empty."
        }

        Write-Host ""
        Write-Host "============================================================"
        Write-Host "Processing server: $ServerName"
        Write-Host "Resource group:    $ResourceGroup"
        Write-Host "Target version:    $TargetVersion"
        Write-Host "General Purpose SKU: $SKU"
        Write-Host "============================================================"

        $CurrentConfigJson = az mysql flexible-server show `
            --resource-group $ResourceGroup `
            --name $ServerName `
            --output json

        if ($LASTEXITCODE -ne 0) {
            throw "Unable to retrieve the current server configuration."
        }

        $CurrentConfig = $CurrentConfigJson | ConvertFrom-Json

        $Result.StartVersion = $CurrentConfig.version

        Write-Host "Current version: $($CurrentConfig.version)"
        Write-Host "Current tier:    $($CurrentConfig.sku.tier)"
        Write-Host "Current SKU:     $($CurrentConfig.sku.name)"
        Write-Host "Current state:   $($CurrentConfig.state)"

        if ($CurrentConfig.version -like "$TargetVersion*") {
            $Result.FinalVersion = $CurrentConfig.version
            $Result.FinalTier = $CurrentConfig.sku.tier
            $Result.FinalSKU = $CurrentConfig.sku.name
            $Result.Status = "Skipped"
            $Result.Message = "Already running MySQL $($CurrentConfig.version)."

            Write-Host $Result.Message
            continue
        }

        if ($CurrentConfig.state -ne "Ready") {
            throw "Server is not Ready. Current state: $($CurrentConfig.state)"
        }

        if ($CurrentConfig.sku.tier -eq "Burstable") {
            Write-Host ""
            Write-Host "Changing server from Burstable to General Purpose..."

            az mysql flexible-server update `
                --resource-group $ResourceGroup `
                --name $ServerName `
                --tier GeneralPurpose `
                --sku-name $SKU

            if ($LASTEXITCODE -ne 0) {
                throw "Failed to change the server to General Purpose."
            }

            Write-Host "Waiting for the tier change to complete..."

            az mysql flexible-server wait `
                --resource-group $ResourceGroup `
                --name $ServerName `
                --custom "state=='Ready'"

            if ($LASTEXITCODE -ne 0) {
                throw "The server did not return to Ready after the tier change."
            }
        }
        elseif ($CurrentConfig.sku.tier -eq "GeneralPurpose") {
            Write-Host "Server is already using the General Purpose tier."
        }
        else {
            Write-Host "Server is using tier '$($CurrentConfig.sku.tier)'."
            Write-Host "No temporary tier change is required."
        }

        $TierCheckJson = az mysql flexible-server show `
            --resource-group $ResourceGroup `
            --name $ServerName `
            --output json

        if ($LASTEXITCODE -ne 0) {
            throw "Unable to verify the server after the tier change."
        }

        $TierCheck = $TierCheckJson | ConvertFrom-Json

        if ($TierCheck.state -ne "Ready") {
            throw "Server is not Ready after the tier change. Current state: $($TierCheck.state)"
        }

        if ($TierCheck.sku.tier -eq "Burstable") {
            throw "Server is still using the Burstable tier."
        }

        Write-Host ""
        Write-Host "Upgrading $ServerName to MySQL $TargetVersion..."

        az mysql flexible-server upgrade `
            --resource-group $ResourceGroup `
            --name $ServerName `
            --version $TargetVersion `
            --yes

        if ($LASTEXITCODE -ne 0) {
            throw "MySQL major-version upgrade failed."
        }

        Write-Host "Waiting for the upgrade to complete..."

        az mysql flexible-server wait `
            --resource-group $ResourceGroup `
            --name $ServerName `
            --custom "state=='Ready'"

        if ($LASTEXITCODE -ne 0) {
            throw "The server did not return to Ready after the upgrade."
        }

        $FinalConfigJson = az mysql flexible-server show `
            --resource-group $ResourceGroup `
            --name $ServerName `
            --output json

        if ($LASTEXITCODE -ne 0) {
            throw "Upgrade completed, but final verification failed."
        }

        $FinalConfig = $FinalConfigJson | ConvertFrom-Json

        $Result.FinalVersion = $FinalConfig.version
        $Result.FinalTier = $FinalConfig.sku.tier
        $Result.FinalSKU = $FinalConfig.sku.name

        if ($FinalConfig.version -notlike "$TargetVersion*") {
            throw "Version verification failed. Current version: $($FinalConfig.version)"
        }

        $Result.Status = "Succeeded"
        $Result.Message = "Upgrade completed successfully."

        Write-Host ""
        Write-Host "Upgrade completed successfully."
        Write-Host "Final version: $($FinalConfig.version)"
        Write-Host "Final tier:    $($FinalConfig.sku.tier)"
        Write-Host "Final SKU:     $($FinalConfig.sku.name)"
    }
    catch {
        $Result.Message = $_.Exception.Message
        Write-Error "[$ServerName] $($Result.Message)"
    }
    finally {
        $Results += [PSCustomObject]$Result
    }
}

Write-Host ""
Write-Host "======================= Upgrade Summary ======================="

$Results |
    Format-Table `
        ServerName,
        ResourceGroup,
        StartVersion,
        FinalVersion,
        FinalTier,
        FinalSKU,
        Status,
        Message `
        -AutoSize

$FailedServers = $Results | Where-Object {
    $_.Status -eq "Failed"
}

if ($FailedServers) {
    Write-Error "$($FailedServers.Count) server upgrade(s) failed."
    exit 1
}

Write-Host ""
Write-Host "All requested server upgrades completed successfully."
exit 0