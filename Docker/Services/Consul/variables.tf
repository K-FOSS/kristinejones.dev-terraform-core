#
# Server Config
#

variable "Name" {
  type = string
}

variable "Peers" {
}


#
# Storage
#
variable "Bucket" {
  type = string
}

#
# Crypto
#
variable "Secret" {
  type = string

  #
  # TODO: Get Testing, Conversion and Validation of this
  #
} 

#
# Misc
#
variable "LogLevel" {
  type = string

  #
  # TODO: Get Validation of this
  #  
}

variable "Version" {
  type = string
}
