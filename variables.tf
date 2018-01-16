variable "password" {}
variable "user_name" {}
variable "tenant_name" {}

variable "ssh_user_name" {
  default = "centos"
}
variable "count_instance" {
  default = 2
}
variable "img_name" {
  default = "CentOS-7-GenericCloud"
}
variable "flavor_name" {
  default = "m1.my"
}
variable "police_name" {
  default = "affinity"
}
