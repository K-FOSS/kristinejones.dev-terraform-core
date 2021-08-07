# KristianFJones/kristianjones.dev-terraform-core

## Usage

Deploy [vps1.kristianjones.dev-CoreSwarm]

Which currently consists of

### Hashicorp

#### CoreVault 
Single Datastore Vault for Tranist

#### Vault
Vault Connected to CoreVault for transit unseal

Configured with the following secret engines

| Name     | Type  | Notes                                                                 |
| -------- | ----- | --------------------------------------------------------------------- |
| keycloak | KV v2 | Need to cleanup and rename as all Consul Terraform Sync ended up here |

And the following secrets

| Path                             | Value                          | Purpose                         | Notes                                         |
| -------------------------------- | ------------------------------ | ------------------------------- | --------------------------------------------- |
| Keycloak/KEYCLOAK_SECRET         | Keycloak Client Secret ID      | Keycloak Terraform Access       | Move to dedicated ConsulTerraformSync Section |
| Keycloak/MINIO/ACCESS_KEY        | Minio Access Key               | Minio Terraform Consul Sync     | Move to dedicated ConsulTerraformSync Section |
| Keycloak/MINIO/SECRET_KEY        | Minio Secret Key               | Minio Terraform Consul Sync     | Move to dedicated ConsulTerraformSync Section |
| Keycloak/OPENLDAP/PASSWORD       | OpenLDAP Server Admin password | OpenLDAP Keycloak Configuration | Move to dedicated OpenLDAP Section            |
| Keycloak/Terraform/CLIENT_SECRET | Honestly I forget              | Honestly I forget               | Audit this and figure it out                  |
| Keycloak/UNIFI/PASSWORD          | Unifi Local Admin Password     | [Unifi Module](./Network/Unifi) | TBD More on this                              |
| Keycloak/UNIFI/USERNAME          | Unifi Local Username           | [Unifi Module](./Network/Unifi) | TBD More on this                              |
| Keycloak/VAULT/TOKEN             | Vault Token                    | I forget                        | Audit this, may have only been temp           |

#### ConsulCore

Consul initial container

### AAA

#### Keycloak

Keycloak AAA Central Auth


#### Ingress

CoreWeb

CoreDNS
CoreWeb
AuthWeb
