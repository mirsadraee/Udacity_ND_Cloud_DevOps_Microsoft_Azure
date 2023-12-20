provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.resource_group_name}"
  location = var.location

  tags = {
    udacity = "${var.resource_group_name}-project-1"
  }

}

// Main virtual network, subnets, nics and public IPs

resource "azurerm_virtual_network" "main" {
  name                = "${var.resource_group_name}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    udacity = "${var.resource_group_name}-project-1"
  }

}

resource "azurerm_subnet" "internal" {
  name                 = "${var.resource_group_name}-internal-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/16"]
}

resource "azurerm_public_ip" "pip" {
  name                = "${var.resource_group_name}-public-ip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Dynamic"

  tags = {
    udacity = "${var.resource_group_name}-project-1"
  }
}

resource "azurerm_network_interface" "main" {
  count               = var.numberofvms
  name                = "${var.resource_group_name}-nic-${count.index}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "${var.resource_group_name}-primary"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    udacity = "${var.resource_group_name}-project-1"
  }
}

// Secutiy Group

resource "azurerm_network_security_group" "webserver" {
  name                = "${var.resource_group_name}-webserver-sg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    udacity = "${var.resource_group_name}-project-1"
  }
}

resource "azurerm_network_security_group" "vnet" {
  name                = "${var.resource_group_name}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    udacity = "${var.resource_group_name}-project-1"
  }
}

resource "azurerm_network_security_rule" "internal-inbound-vnet" {
  name                        = "internal-inbound-rule-vnet"
  resource_group_name         = "${azurerm_resource_group.main.name}"
  network_security_group_name = "${azurerm_network_security_group.vnet.name}"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"

}



resource "azurerm_network_security_rule" "internal-inbound" {
  name                        = "internal-inbound-rule"
  resource_group_name         = "${azurerm_resource_group.main.name}"
  network_security_group_name = "${azurerm_network_security_group.webserver.name}"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.0.0.0/16"
  destination_address_prefix  = "10.0.0.0/16"
}

resource "azurerm_network_security_rule" "internal-outbound" {
  name                        = "internal-outbound-rule"
  resource_group_name         = "${azurerm_resource_group.main.name}"
  network_security_group_name = "${azurerm_network_security_group.webserver.name}"
  priority                    = 102
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.0.0.0/16"
  destination_address_prefix  = "10.0.0.0/16"
}

resource "azurerm_network_security_rule" "external" {
  name                        = "external-rule"
  resource_group_name         = "${azurerm_resource_group.main.name}"
  network_security_group_name = "${azurerm_network_security_group.webserver.name}"
  priority                    = 103
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

// Load balancer

resource "azurerm_lb" "main" {
  name                = "${var.resource_group_name}-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  frontend_ip_configuration {
    name                 = "${var.resource_group_name}-public-address"
    public_ip_address_id = azurerm_public_ip.pip.id
  }

  tags = {
    udacity = "${var.resource_group_name}-project-1"
  }
}

resource "azurerm_lb_backend_address_pool" "main" {
  loadbalancer_id     = azurerm_lb.main.id
  name                = "${var.resource_group_name}-backend-address-pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "main" {
  count                   = var.numberofvms
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
  ip_configuration_name   = "${var.resource_group_name}-primary"
  network_interface_id    = element(azurerm_network_interface.main.*.id, count.index)
}

resource "azurerm_availability_set" "avset" {
  name                = "${var.resource_group_name}-avset"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    udacity = "${var.resource_group_name}-project-1"
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  count                           = var.numberofvms
  name                            = "${var.resource_group_name}-vm-${count.index}"
  resource_group_name             = azurerm_resource_group.main.name
  source_image_id                 = var.image_id
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_D3_v2"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  availability_set_id             = azurerm_availability_set.avset.id
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.main[count.index].id,
  ]

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  tags = {
    udacity = "${var.resource_group_name}-project-1"
  }
}

resource "azurerm_managed_disk" "data" {
  count                = var.numberofvms
  name                 = "${var.resource_group_name}-disk-${count.index}"
  location             = azurerm_resource_group.main.location
  create_option        = "Empty"
  disk_size_gb         = 10
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Standard_LRS"

  tags = {
    udacity = "${var.resource_group_name}-project-1"
  }

}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  virtual_machine_id = element(azurerm_linux_virtual_machine.main.*.id, count.index)
  managed_disk_id    = element(azurerm_managed_disk.data.*.id, count.index)
  lun                = 1
  caching            = "None"
  count              = var.numberofvms
}