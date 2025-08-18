# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the `rainforest-homelab` project.

## Project Overview

This project is a Terraform-based homelab infrastructure that deploys various self-hosted applications to a Kubernetes cluster. It uses Docker Desktop as the local Kubernetes environment and Cloudflare Tunnel for secure external access with automatic SSL certificates and optional Zero Trust authentication.

## Architecture

*   **Terraform:** Used for Infrastructure as Code to manage Kubernetes resources.
*   **Helm:** Used as a package manager for Kubernetes applications.
*   **Cloudflare Tunnel:** Provides secure external access to services with automatic SSL certificates.
*   **Docker Desktop:** The local Kubernetes cluster environment.
*   **Docker Volumes:** Used for managed persistent storage for applications.

## Building and Running

1.  **Prerequisites:**
    *   Docker Desktop with Kubernetes enabled.
    *   Terraform >= 1.0.
    *   `kubectl` configured with the `docker-desktop` context.
    *   A domain managed by Cloudflare.
    *   A Cloudflare account.

2.  **Installation:**
    1.  Clone the repository.
    2.  Obtain Cloudflare credentials (API Token and Account ID).
    3.  Configure the environment by copying `terraform.tfvars.example` to `terraform.tfvars` and editing it with your Cloudflare credentials and domain.
    4.  Deploy the infrastructure using `terraform init`, `terraform plan`, and `terraform apply`.

## Development Conventions

*   **Infrastructure as Code:** All infrastructure and application definitions are managed in version control.
*   **Modularity:** The project is highly modular, with each service defined in its own Terraform module.
*   **Standardized Module Structure:** Each module follows a consistent structure with `main.tf`, `variables.tf`, `outputs.tf`, and optional `versions.tf`.
*   **Secure by Default:** The project emphasizes security with features like Cloudflare Tunnel, automatic SSL, and optional Zero Trust authentication.
*   **Clear Separation of Concerns:** The project separates the concerns of infrastructure, application deployment, and configuration.

## Key Files

*   `README.md`: The main entry point for understanding the project.
*   `main.tf`: The root Terraform file that defines the providers and modules.
*   `versions.tf`: Specifies the required versions for Terraform and the providers.
*   `variables.tf`: Defines the input variables for the Terraform configuration.
*   `terraform.tfvars.example`: An example of the `terraform.tfvars` file, which is used to provide user-specific values for the input variables.
*   `modules/`: This directory contains the Terraform modules for each service and core components like the Cloudflare Tunnel and volume management.
