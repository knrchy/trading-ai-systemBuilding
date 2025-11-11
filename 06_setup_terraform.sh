#!/bin/bash

# Install Terraform
echo "Installing Terraform..."

# Add HashiCorp GPG key
sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add the HashiCorp repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Update and install Terraform
sudo apt update && sudo apt install -y terraform

# Verify the installation
echo "Verifying Terraform installation..."
terraform --version

# Create the directory for Terraform files
mkdir -p ~/trading-ai-system/infrastructure/terraform

# Navigate to the Terraform directory
cd ~/trading-ai-system/infrastructure/terraform

echo "importing previous namespaces and storage class created before with other resoucers"
terraform import kubernetes_namespace.trading_system trading-system
terraform import kubernetes_namespace.monitoring monitoring
terraform import kubernetes_namespace.databases databases
terraform import kubernetes_storage_class.local_storage local-storage
terraform import kubernetes_persistent_volume.data_storage trading-data-pv
terraform import kubernetes_persistent_volume.models_storage models-pv

# Main Terraform configuration file
cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.28"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# Namespaces
resource "kubernetes_namespace" "trading_system" {
  metadata {
    name = "trading-system"
    labels = {
      name        = "trading-system"
      environment = var.environment
    }
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name        = "monitoring"
      environment = var.environment
    }
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "kubernetes_namespace" "databases" {
  metadata {
    name = "databases"
    labels = {
      name        = "databases"
      environment = var.environment
    }
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}

# Storage Class for local storage
resource "kubernetes_storage_class" "local_storage" {
  metadata {
    name = "local-storage"
  }
  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = "WaitForFirstConsumer"

  lifecycle {
    ignore_changes = [metadata]
  }
}

# Persistent Volumes
resource "kubernetes_persistent_volume" "data_storage" {
  metadata {
    name = "trading-data-pv"
  }
  spec {
    capacity = {
      storage = "5Gi"
    }
    access_modes = ["ReadWriteMany"]
    persistent_volume_source {
      host_path {
        path = "/mnt/trading-data"
        type = "DirectoryOrCreate"
      }
    }
    storage_class_name = kubernetes_storage_class.local_storage.metadata[0].name
  }
}

resource "kubernetes_persistent_volume" "models_storage" {
  metadata {
    name = "models-pv"
  }
  spec {
    capacity = {
      storage = "100Gi"
    }
    access_modes = ["ReadWriteMany"]
    persistent_volume_source {
      host_path {
        path = "/mnt/models"
        type = "DirectoryOrCreate"
      }
    }
    storage_class_name = kubernetes_storage_class.local_storage.metadata[0].name
  }
}
EOF

# Variables file
cat > variables.tf << 'EOF'
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "trading-ai-cluster"
}

variable "monitoring_enabled" {
  description = "Enable monitoring stack"
  type        = bool
  default     = true
}

variable "data_storage_size" {
  description = "Size of data storage in Gi"
  type        = string
  default     = "5Gi"
}

variable "models_storage_size" {
  description = "Size of models storage in Gi"
  type        = string
  default     = "100Gi"
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "default_cpu_limit" {
  description = "Default CPU limit for containers"
  type        = string
  default     = "2000m"
}

variable "default_memory_limit" {
  description = "Default memory limit for containers"
  type        = string
  default     = "2Gi"
}

variable "enable_gpu" {
  description = "Enable GPU support for ML workloads"
  type        = bool
  default     = false
}

variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}
EOF

# Outputs file
cat > outputs.tf << 'EOF'
output "namespaces" {
  description = "Created namespaces"
  value = {
    trading_system = kubernetes_namespace.trading_system.metadata[0].name
    monitoring     = kubernetes_namespace.monitoring.metadata[0].name
    databases      = kubernetes_namespace.databases.metadata[0].name
  }
}

output "storage_class" {
  description = "Storage class name"
  value       = kubernetes_storage_class.local_storage.metadata[0].name
}

output "persistent_volumes" {
  description = "Created persistent volumes"
  value = {
    data_pv   = kubernetes_persistent_volume.data_storage.metadata[0].name
    models_pv = kubernetes_persistent_volume.models_storage.metadata[0].name
  }
}

output "cluster_info" {
  description = "Cluster information"
  value = {
    name        = var.cluster_name
    environment = var.environment
  }
}

output "storage_paths" {
  description = "Host storage paths"
  value = {
    data_path   = "/mnt/trading-data"
    models_path = "/mnt/models"
  }
}
EOF

# Monitoring configuration file
cat > monitoring.tf << 'EOF'
#################################################
# Wait for Prometheus CRDs to be available
#################################################
resource "null_resource" "wait_for_crd" {
  count = var.monitoring_enabled ? 1 : 0

  # Trigger ensures wait only happens after Helm release is created
  triggers = {
    release_name = helm_release.prometheus[0].name
  }

  provisioner "local-exec" {
    command = "sleep 30" # Wait for 30 seconds to allow the API server to catch up
  }

  depends_on = [helm_release.prometheus]
}

#################################################
# Helm Release: Prometheus + Grafana + Alertmanager
#################################################
resource "helm_release" "prometheus" {
  count       = var.monitoring_enabled ? 1 : 0
  name        = "prometheus"
  repository  = "https://prometheus-community.github.io/helm-charts"
  chart       = "kube-prometheus-stack"
  namespace   = kubernetes_namespace.monitoring.metadata[0].name
  version     = "51.0.0"

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = "30d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "50Gi"
                  }
                }
              }
            }
          }
          resources = {
            requests = {
              memory = "2Gi"
              cpu    = "1000m"
            }
            limits = {
              memory = "2Gi"
              cpu    = "1000m"
            }
          }
        }
      }
      grafana = {
        enabled        = true
        adminPassword  = "admin" # Change in production!
        service = {
          type     = "NodePort"
          nodePort = 30300
        }
        persistence = {
          enabled = true
          size    = "10Gi"
        }
      }
      alertmanager = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

#################################################
# ServiceMonitor for custom trading metrics
#################################################
resource "kubernetes_manifest" "trading_service_monitor" {
  count = var.monitoring_enabled ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "trading-metrics"
      namespace = kubernetes_namespace.trading_system.metadata[0].name
      labels = {
        release = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "trading-api"
        }
      }
      endpoints = [
        {
          port     = "metrics"
          interval = "30s"
          path     = "/metrics"
        }
      ]
    }
  }

  # Explicit dependency on the wait resource
  depends_on = [
    null_resource.wait_for_crd,
    kubernetes_namespace.trading_system
  ]
}
EOF

# Providers file
#cat > providers.tf << 'EOF'
#terraform {
#  required_version = ">= 1.0"
#  
#  required_providers {
#    kubernetes = {
#      source  = "hashicorp/kubernetes"
#      version = "~> 2.23"
#    }
#    helm = {
#      source  = "hashicorp/helm"
#      version = "~> 2.11"
#    }
#    local = {
#      source  = "hashicorp/local"
#      version = "~> 2.4"
#    }
#  }
#
#  backend "local" {
#    path = "terraform.tfstate"
#  }
#}
#
#provider "kubernetes" {
#  config_path = var.kubeconfig_path
#}
#
#provider "helm" {
#  kubernetes {
#    config_path = var.kubeconfig_path
#  }
#}
#
#provider "local" {}
#EOF

# Terraform variables file
cat > terraform.tfvars << 'EOF'
# Environment Configuration
environment     = "development"
cluster_name    = "trading-ai-cluster"

# Monitoring
monitoring_enabled = true

# Storage
data_storage_size   = "5Gi"
models_storage_size = "100Gi"

# Kubernetes Config
kubeconfig_path = "~/.kube/config"

# Resource Limits
default_cpu_limit    = "1000m"
default_memory_limit = "2Gi"
EOF

echo "Terraform configuration files created successfully."
