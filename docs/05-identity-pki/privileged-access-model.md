# Privileged Access Model

## Principle

Privileged administration must be separated from daily-use activity.

## Accounts

Standard account:
lab-admin

Privileged account:
domain-admin

## Workstations

ws-admin:
Privileged administrative workstation

ws01:
Standard workstation

ws02:
Standard workstation

## Rules

- Standard users log into ws01 and ws02.
- Administrative users perform privileged tasks from ws-admin.
- Domain administration should not be performed from standard workstations.
- Cyber range accounts remain completely separate.

## Administrative Tiers

Tier 0:
dc01, future ca01, identity infrastructure

Tier 1:
servers and infrastructure services

Tier 2:
workstations and standard user systems
