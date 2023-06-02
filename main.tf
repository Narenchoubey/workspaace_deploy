provider "google" {
  #credentials = file("./ninth-beacon-388117-d7f8eeedc1e1.json")
  credentials = "${var.google_cred}"
  project     = "ninth-beacon-388117"
  region      = "us-central1"
}
###############################################################
variable "my_secret_pub" {
  description = "My secret value"
}

variable "my_secret_pvt" {
  description = "My secret value"
}

variable "google_cred" {
  description = "My secret value"
}
##########################################################################################
## NETWORK and FIREWALL
##########################################################################################

resource "google_compute_network" "network" {
  name    = "test-dev-vpc"
  project = "ninth-beacon-388117"
#  network_tier   =  "STANDARD"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "app-sub1"
  project       = "ninth-beacon-388117"
  region        = "us-central1"
  network       = google_compute_network.network.id
  ip_cidr_range = "10.1.0.0/27"
}

resource "google_compute_address" "static-ip-address" {
  name   = "gke-ip"
  region = "us-central1"
  #network_tier = "STANDARD"
}


#terraform import google_compute_network.network manh-cloud-services-sandbox/test-dev-vpc

resource "google_compute_instance" "default" {
  count         = 1
  name         = "test001-${count.index + 2}"
  machine_type = "n1-standard-1"
  zone         = "us-central1-c"

  tags = ["testing"]

  boot_disk {
    initialize_params {
      image = "rhel-cloud/rhel-8"
      size ="${var.boot_size}"
    }
  }

  // Local SSD disk
  scratch_disk {
    interface = "SCSI"
  }

  network_interface {
    subnetwork = "app-sub1"

    access_config {
      nat_ip = "${google_compute_address.static-ip-address.address}"
    }
  }
  
    provisioner "remote-exec" {
    on_failure = continue
    connection {
        type     = "ssh"
        timeout  = "5m"
        user     = "gcp"
        host = "${google_compute_address.static-ip-address.address}"
#        host = "${google_compute_address.static-ip-address[count.index].address}"
        #private_key = "${file("./gcp.pem")}"
		private_key = "${var.my_secret_pub}"
    }
    inline=[
      "sleep 5",
      "sudo yum update -y",
      "sudo subscription-manager repos --enable ansible-2-for-rhel-8-x86_64-rpms",
      "sudo yum install ansible -y"

      ]
  }

  metadata = {
    ssh-keys = "gcp:${var.my_secret_pvt}"
	#ssh-keys = "gcp:${file("./gcp.pub")}"
  }

  metadata_startup_script = "echo hi > /test.txt"

}



resource "local_file" "inventory" {
  content = <<-EOT
    ${join("\n", [google_compute_address.static-ip-address.address])}
  EOT

  filename = "inventory.ini"
}

#resource "null_resource" "change_permission" {
#  provisioner "local-exec" {
#    command     = "chmod 600 ./gcp.pem"
#    working_dir = "./"
#  }
#}
#
#resource "null_resource" "ansible_provisioner" {
#  provisioner "local-exec" {
#    command = "sleep 180 && ansible-playbook -i inventory.ini ./Ansible/install_security.yml -u gcp --private-key=./keys/gcp.pem -vv"
#    working_dir = "./"
#	environment = {
#      ANSIBLE_PRIVATE_KEY_FILE = "./gcp.pub"
#    }
#  }
#
#  depends_on = ["local_file.inventory", "google_compute_address.static-ip-address", "google_compute_instance.vm_instance"]
#}