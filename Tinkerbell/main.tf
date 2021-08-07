terraform {
  required_providers {
    consul = {
      source = "hashicorp/consul"
      version = "2.12.0"
    }

    tls = {
      source = "hashicorp/tls"
      version = "3.1.0"
    }

    # tinkerbell = {
    #   source  = "github.com/tinkerbell/terraform-provider-tinkerbell.git"
    # }
  }
}

provider "tinkerbell" {
  grpc_authority = "TinkServer:42113"
  cert_url       = "http://TinkServer:42114/cert"
}

resource "tinkerbell_hardware" "foo" {
  data = <<EOF
{
  "id": "2bd4b2b3-3104-4f67-8b5c-3d208d9cd1cd",
  "metadata": {
    "facility": {
      "facility_code": "vps1",
      "plan_slug": "c2.medium.x86",
      "plan_version_slug": ""
    },
    "instance": {
      "crypted_root_password": "redacted",
      "operating_system_version": {
        "distro": "ubuntu",
        "os_slug": "ubuntu_20_10",
        "version": "20.10"
      }
    },
    "state": "provisioning"
  },
  "network": {
    "interfaces": [
      {
        "dhcp": {
          "arch": "x86_64",
          "hostname": "server001",
          "ip": {
            "address": "172.16.100.35",
            "gateway": "172.16.100.1",
            "netmask": "255.255.255.0"
          },
          "mac": "b8:ae:ed:79:5e:1d"
        },
        "netboot": {
          "allow_pxe": true,
          "allow_workflow": true
        }
      }
    ]
  }
}
EOF
}

resource "tinkerbell_template" "foo" {
  name    = "foo"
  content = <<EOF
version: "0.1"
name: ubuntu_provisioning
global_timeout: 6000
tasks:
  - name: "os-installation"
    worker: "{{.device_1}}"
    volumes:
      - /dev:/dev
      - /dev/console:/dev/console
      - /lib/firmware:/lib/firmware:ro
    environment:
      MIRROR_HOST: 172.16.100.33
    actions:
      - name: "disk-wipe"
        image: disk-wipe
        timeout: 90
      - name: "disk-partition"
        image: disk-partition
        timeout: 600
        environment:
          MIRROR_HOST: 172.16.100.33
        volumes:
          - /statedir:/statedir
      - name: "install-root-fs"
        image: install-root-fs
        timeout: 600
      - name: "install-grub"
        image: install-grub
        timeout: 600
        volumes:
          - /statedir:/statedir
EOF
}

resource "tinkerbell_workflow" "foo" {
    template  = tinkerbell_template.foo.id
  hardwares = <<EOF
{"device_1":"b8:ae:ed:79:5e:1d"}
EOF

  depends_on = [
    tinkerbell_hardware.foo,
  ]
}