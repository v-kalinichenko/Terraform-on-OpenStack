### [Openstack Demo] ###

provider "openstack" {
  user_name = "${var.user_name}"
  tenant_name = "${var.tenant_name}"
  password = "${var.password}"
  auth_url = "http://192.168.103.234:5000/v2.0"
}

resource "openstack_networking_router_v2" "router" {
  name = "router1"
  admin_state_up = "true"
  external_gateway = "ba487cf2-8b3e-4b92-b4af-4117b151c8b0"
}

resource "openstack_compute_keypair_v2" "demo_keypair" {
  name = "demo-keypair"
  region = ""
  public_key = "${file("cloud.key.pub")}"
}

resource "openstack_compute_secgroup_v2" "ssh_sg" {
  name = "demo-ssh-sg"
  description = "ssh security group"
  rule {
    from_port = 22
    to_port = 22
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
}

resource "openstack_compute_secgroup_v2" "web_sg" {
  name = "demo-web-sg"
  description = "web security group"
  rule {
    from_port = 80
    to_port = 80
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 443
    to_port = 443
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
         from_port = -1
         to_port = -1
         ip_protocol = "icmp"
         cidr = "0.0.0.0/0"
    }
}

resource "openstack_compute_secgroup_v2" "db_sg" {
  name = "demo-db-sg"
  description = "db security group"
  rule {
    from_port = 3306
    to_port = 3306
    ip_protocol = "tcp"
    cidr = "${openstack_networking_subnet_v2.web_subnet.cidr}"
  }
}

### [Web networking] ###

resource "openstack_networking_network_v2" "web_net" {
  name = "demo-web-net"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "web_subnet" {
  name = "demo-web-subnet"
  network_id = "${openstack_networking_network_v2.web_net.id}"
  cidr = "10.0.0.0/24"
  ip_version = 4
  enable_dhcp = "true"
  dns_nameservers = ["8.8.8.8","8.8.4.4"]
}

resource "openstack_networking_router_interface_v2" "web-ext-interface" {
  router_id = "${openstack_networking_router_v2.router.id}"
  subnet_id = "${openstack_networking_subnet_v2.web_subnet.id}"
}

resource "openstack_compute_floatingip_v2" "fip" {
  count = "${var.count_instance}"
  pool = "public"
}

### [Web instances] ###

resource "openstack_compute_servergroup_v2" "web_srvgrp" {
  name = "demo-web-srvgrp"
  policies = ["${var.police_name}"]
}

resource "openstack_compute_instance_v2" "web_cluster" {
  name = "demo-web-${count.index+1}"
  count = "${var.count_instance}"
  image_name = "${var.img_name}"
  flavor_name = "${var.flavor_name}"
  network = { 
  uuid = "${openstack_networking_network_v2.web_net.id}"
  }
  key_pair = "${openstack_compute_keypair_v2.demo_keypair.name}"
  scheduler_hints {
  group = "${openstack_compute_servergroup_v2.web_srvgrp.id}"
  }
  security_groups = ["${openstack_compute_secgroup_v2.ssh_sg.name}","${openstack_compute_secgroup_v2.web_sg.name}"]
  user_data = "${var.ssh_user_name}"
}


    resource "null_resource" "ServiceProvision" {
    count = "${var.count_instance}"
    triggers {
    current_openstack_instance_id = "${element(openstack_compute_instance_v2.web_cluster.*.id, count.index)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install epel-release -y",
      "sudo yum install nginx -y",
      "sudo service nginx start",
      "sudo systemctl enable nginx",
]
    connection {
      type     = "ssh"
      host     = "${element(openstack_compute_floatingip_v2.fip.*.address, count.index)}"
      private_key = "${file("cloud.key")}"
      user     = "${var.ssh_user_name}"
      agent    = false
      timeout  = "1m"
    }
  }
}


resource "openstack_compute_floatingip_associate_v2" "fip_assoc" {
  count = "${var.count_instance}"
  floating_ip = "${element(openstack_compute_floatingip_v2.fip.*.address, count.index)}"
  instance_id = "${element(openstack_compute_instance_v2.web_cluster.*.id, count.index)}"
}

output "external_web_instances" {
  value = "${join(",", openstack_compute_floatingip_associate_v2.fip_assoc.*.floating_ip)}"
}
output "internal_web_instances" {
  value = "${join( "," , openstack_compute_instance_v2.web_cluster.*.access_ip_v4) }"
}



### [DB networking] ###

resource "openstack_networking_network_v2" "db_net" {
  name = "demo-db-net"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "db_subnet" {
  name = "demo-db-subnet"
  network_id = "${openstack_networking_network_v2.db_net.id}"
  cidr = "10.0.1.0/24"
  ip_version = 4
  enable_dhcp = "true"
  dns_nameservers = ["8.8.8.8","8.8.4.4"]
}

resource "openstack_networking_router_interface_v2" "db-ext-interface" {
  router_id = "${openstack_networking_router_v2.router.id}"
  subnet_id = "${openstack_networking_subnet_v2.db_subnet.id}"
}

### [DB instances] ###

resource "openstack_compute_servergroup_v2" "db_srvgrp" {
  name = "demo-db-srvgrp"
  policies = ["${var.police_name}"]
}

resource "openstack_compute_instance_v2" "db_cluster" {
  name = "demo-db-${count.index+1}"
  count = "${var.count_instance}"
  image_name = "${var.img_name}"
  flavor_name = "${var.flavor_name}"
  network = { 
    uuid = "${openstack_networking_network_v2.db_net.id}"
  }
  key_pair = "${openstack_compute_keypair_v2.demo_keypair.name}"
  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.db_srvgrp.id}"
  }
  security_groups = ["${openstack_compute_secgroup_v2.ssh_sg.name}","${openstack_compute_secgroup_v2.db_sg.name}"]
  user_data = "${var.ssh_user_name}"
}

output "internal_db_instances" {
  value = "${join( "," , openstack_compute_instance_v2.db_cluster.*.access_ip_v4) }"
}


### [Web LB] ###

resource "openstack_lb_loadbalancer_v2" "lb_1" {
	name = "demo_lb_1"
        vip_subnet_id = "${openstack_networking_subnet_v2.web_subnet.id}"
        vip_address = "10.0.0.100"
#       security_group_ids = "${openstack_compute_secgroup_v2.web_sg.id}"
        admin_state_up = "true"
}

resource "openstack_lb_monitor_v2" "monitor_1" {
  pool_id     = "${openstack_lb_pool_v2.pool_1.id}"
  type        = "PING"
  delay       = 20
  timeout     = 10
  max_retries = 5
  admin_state_up = "true"
}

resource "openstack_lb_member_v2" "members_1" {
  count = "${var.count_instance}"
  pool_id = "${openstack_lb_pool_v2.pool_1.id}"
  subnet_id = "${openstack_networking_subnet_v2.web_subnet.id}"
  address = "${element(openstack_compute_instance_v2.web_cluster.*.access_ip_v4, count.index)}"
  protocol_port = 80
  admin_state_up = "true"
}

resource "openstack_lb_listener_v2" "listener_1" {
  name = "demo_listener_1"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = "${openstack_lb_loadbalancer_v2.lb_1.id}"

  depends_on = [
        "openstack_lb_loadbalancer_v2.lb_1",
    ]
  admin_state_up = "true"
}

resource "openstack_lb_pool_v2" "pool_1" {
  name        = "demo_pool_1"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = "${openstack_lb_listener_v2.listener_1.id}"
  persistence {
  type        = "SOURCE_IP"
 }
  admin_state_up = "true"
}

resource "openstack_networking_floatingip_v2" "lb_fip" {
  region = ""
  pool   = "public"
  port_id = "${openstack_lb_loadbalancer_v2.lb_1.vip_port_id}"
}


output "loadbalanser_external_address" {
  value = "${join(",", openstack_networking_floatingip_v2.lb_fip.*.address)}"
}
