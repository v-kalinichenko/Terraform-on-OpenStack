# Infrastructure with Terraform on OpenStack Demo

This is just a quickstart for using terraform on Demo. It creates:

| \# | Resource |
|----|----------|
1 | Router
2 | Subnets, web and db
3 | instances, 2 web, 2 db
4 | floating IPs for web cluster
5 | Server Groups with **`anti-affiniy`** (web, db) makes sure instances aren't on same physical hardware
6 | Security Groups "demo-ssh-sg", "demo-web-sg" and "demo-db-sg"
7 | Key pair "demo\_rsa"


## File structure
| Name | Description |
|------|-------------|
README.md | This file, obviously
cloud.key(\|\\.pub) | SSH keypair, only to be used for this demonstration
demo1.tf | The terraform manifest with all defined resources
terraform-openrc.sh | should be run initially to setup username, tenant and password
terraform.tfstate(\|\\.backup) | tfstate and tfstate.backup so that terraform can keep track on changes


## How to use

Make sure you have installed [Terraform](https://www.terraform.io/)

First off, run the terraform-openrc.sh script. It will ask about username, tenant and password. Then run "terraform plan". If that fails, make sure you've used the correct credentials (runt terraform-openrc.sh again)

Last, "terraform apply" will install

```bash
$ . ./terraform-openrc.sh
[...]
$ terraform plan
$ terraform apply
```

You should now have a fully working environment with everything described in the beginning of this README.

