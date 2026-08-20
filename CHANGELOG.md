# Changelog

All notable changes to this project will be documented in this file. This project adheres to [Calendar Versioning](https://calver.org/).

The category for each release must be one of (in order):

* `[ref]` enhanced/modified existing functionality
* `[add]` added new functionality
* `[del]` removed existing functionality
* `[fix]` fixed bug/issue

## To-do
- upgrade should only change tier if it's burstable

## Released

### [2026.08-r1] - 2026.08-r1

* 2026.08.05 : doc : added release-specific documentation [`docs/upgrade-mysql80-to84.md`] for [`mysql/upgrades/upgrade-mysql80-to84.ps1`]
* 2026.08.05 : ref : refactored upgrade script to read server inventory from an external CSV configuration file instead of hardcoded values
* 2026.08.05 : ref : support upgrading multiple Azure MySQL Flexible Servers in a single execution
* 2026.08.05 : ref : added configurable target MySQL version parameter
* 2026.08.05 : ref : added automatic Burstable to General Purpose tier conversion before major version upgrade
* 2026.08.05 : ref : added post-upgrade verification and execution summary report
* 2026.08.05 : ref : added validation for required CSV columns and empty server list detection
* 2026.08.05 : ref : trimmed whitespace from CSV values to prevent Azure CLI SKU validation errors
* 2026.08.05 : fix : improved error handling to continue processing remaining servers when an individual server upgrade fails
* 2026.08.05 : fix : added validation to ensure servers are in the Ready state before and after tier changes and upgrades
* 2026.08.05 : doc : added project README with prerequisites, configuration, usage examples, and repository structure
- 2026.08.05 : ref : renamed [`mysql/upgrades/upgrade-mysql.ps1`] to [`mysql/upgrades/upgrade-mysql80-to84.ps1`] to reflect the supported upgrade path
* 2026.07.30 : doc : track changes to project [`CHANGELOG.md`](CHANGELOG.md)
* 2026.07.21 : add : initial Azure MySQL Flexible Server major upgrade automation [`upgrade-az-myql.ps1`]
