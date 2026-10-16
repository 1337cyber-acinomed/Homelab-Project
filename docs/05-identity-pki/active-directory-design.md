# Active Directory Design

## Domain

Forest:
polaris.home.arpa

Domain:
polaris.home.arpa

Domain Controller:
dc01

VMID:
200

OS:
Windows Server 2019 Evaluation

Functional Level:
Windows Server 2016

## Purpose

Production Active Directory provides secure identity services for the trusted homelab network.

It does not support intentionally vulnerable configurations.

## DNS

Clients use firewall01 as DNS.

pfSense forwards polaris.home.arpa queries to dc01 after AD DNS deployment.

## Time

firewall01 provides time to dc01.

dc01 provides time to domain members.

## Production Scope

Initial domain systems:

- dc01
- ws-admin
- ws01
- ws02

Family devices are not joined unless later explicitly approved.

## Cyber Range

Cyber range AD will be separate and isolated.
