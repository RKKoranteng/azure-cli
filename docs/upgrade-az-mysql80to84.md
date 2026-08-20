# docs : upgrade-az-mysql80to84.md

Documentation for Azure MySQL Flexible Database Server major version upgrades script [`upgrade-az-mysql80to84.ps1`](../mysql/upgrades/upgrade-az-mysql80to84.ps1).

Upgrade one or more servers by reading a CSV configuration file. 

- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Usage](#usage)
- [What the Script Does](#what-the-script-does)
- [Example Output](#example-output)
- [Exit Codes](#exit-codes)
- [Notes](#notes)


## Prerequisites
- Azure CLI installed
- PowerShell 7+ (recommended)
- Appropriate Azure RBAC permissions to update Azure MySQL Flexible Servers
- Logged into Azure
    - `az login`
    - Select the appropriate subscription if necessary.
    - `az account set --subscription "<subscription-name-or-id>"`
    - `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`

## Configuration

The script reads servers from a CSV file in [env directory](../mysql/upgrades/env/)

Example of how CSV should be formatted:

```csv
ResourceGroup,ServerName,SKU
rg-dev,mysql-demo-db1,Standard_D2ds_v4
rg-dev,mysql-demo-db2,Standard_D2ds_v4
```

Fields:

| Column        | Description                                                             |
| ------------- | ----------------------------------------------------------------------- |
| ResourceGroup | Azure Resource Group containing the MySQL server                        |
| ServerName    | Azure MySQL Flexible Server name                                        |
| SKU           | Temporary General Purpose SKU used if the server is currently Burstable |

## Usage

Run using positional parameter:

```powershell
.\upgrade-az-mysql80to84.ps1 .\env\<server-file>.csv
```

or

```powershell
.\upgrade-az-mysql80to84.ps1 -ServerListFile .\env\<server-file>.csv
```

or

Specify a different target version:

```powershell
.\upgrade-az-mysql80to84.ps1 -ServerListFile .\env\<server-file>.csv -TargetVersion 8.4
```

## What the Script Does

For each server, the script:

1. Retrieves the current server configuration.
1. Skips servers already running the target version.
1. Validates the server is in the **Ready** state.
1. Changes Burstable servers to **General Purpose** (if required).
1. Waits for the tier change to complete.
1. Performs the MySQL major version upgrade.
1. Waits for the upgrade to complete.
1. Verifies the final version.
1. Records the result.
1. Continues to the next server.

## Example Output

```text
============================================================
Processing server: dev-dba-1
Current version: 8.0.21
Current tier: Burstable

Changing server to General Purpose...
Waiting for tier change...

Upgrading to MySQL 8.4...
Waiting for upgrade...

Upgrade completed successfully.
```

Summary:

```text
ServerName      Status      FinalVersion
--------------  ----------  ------------
dev-dba-1       Succeeded   8.4.6
dev-dba-2       Skipped     8.4.6
dev-dba-3       Failed
```

## Exit Codes

| Code | Meaning                                       |
| ---- | --------------------------------------------- |
| 0    | All requested upgrades completed successfully |
| 1    | One or more server upgrades failed            |

## Notes

* Major version upgrades are **irreversible**.
* Burstable servers must temporarily be converted to **General Purpose** before upgrading.
* Existing connections will be interrupted while Azure performs the compute change and version upgrade.
* Always validate application compatibility before upgrading production environments.
