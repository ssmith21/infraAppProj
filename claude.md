# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Azure-based infrastructure managed as Bicep IaC. Designed for a microservices application using Azure Container Apps, with a layered networking model for security isolation. Azure subscription is a Visual Studio Enterprise (MSDN) subscription billed in CAD.

## IaC Stack

- **Bicep** (Azure-native, compiles to ARM) for all Azure resources
- **No Terraform** — Bicep only
- Deployments via Azure CLI (`az deployment`)
- All changes should be done in code, instead of by running scripts or az commands.

# Infrastructure

Apps should be hosted on AKS clusters. There is no dev or prod, since this is a sandbox project. This should be a minimal code required project. The less code, and the less components, the better.

## Security

I want to learn about security concepts. The cluster should be secure, using as many security concepts as possible. The app should be secure, yet easy to access.

## Cost

I have a $200 a month allowance for this subscription. Keep cost to the absolute minimum, while meeting the minimum requirements to make the app functional and secure. Have the cluster only run from 10am to 6pm EST to save running cost.

## Learning

Document the architecture with architecture diagrams saved as images. Update the diagram each time the architecture changes.
Maintain a comprehensive yet short readme where I can read and learn about different security and architecture concepts.

# App

We will get to funtionality the app later.
For now, create a bare-minimum htlm welcome page.
Let me know how I can access the webpage.