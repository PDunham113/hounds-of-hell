# -*- mode: ruby -*-
# vi: set ft=ruby :


################################################################################
# Custom configurations
################################################################################

# Define Vagrantfile locations
ex_vagrantfile = File.expand_path("./Vagrantfile.local.example", __dir__)
local_vagrantfile = File.expand_path('./Vagrantfile.local', __dir__)
project_vagrantfile = File.expand_path('./Vagrantfile.project', __dir__)

# Load project configurations.
load project_vagrantfile if File.exists?(project_vagrantfile)

# Load local configurations. If they don't exist, copy the example Vagrantfile.
if !File.exists?(local_vagrantfile)
  print "Creating local Vagrantfile...\n"
  FileUtils.cp(ex_vagrantfile, local_vagrantfile)
end

load local_vagrantfile


################################################################################
# Provisioning Scripts
################################################################################

# Use the current Git SHA1 as the VM version number.
$vm_version = `git rev-parse HEAD`


################################################################################
# VM Configuration
################################################################################

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "bento/ubuntu-20.04" # BBBs are on Debian 7 (Wheezy)


  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  config.vm.synced_folder "./", "/home/vagrant/#{$project_name}/"

  # Enable X11 forwarding.
  config.ssh.forward_x11 = true
  config.ssh.forward_agent = true

  # Add them to the public network (scary)
  config.vm.network :public_network

  # Add SSH keys
  if $ssh_public_key != ""
    config.vm.provision "file",
    source: "#{$ssh_key_location}/#{$ssh_public_key}",
    destination: "~/.ssh/#{$ssh_public_key}"
  end

  # Copy global file lists
  for file in $files
    if File.exists?(file)
      file.sub! "#{ENV['HOME']}", "~/"
      config.vm.provision "file", source: file, destination: file
    end
  end

  # Store the version of the Vagrant configuration used to provision the VM.
  config.vm.provision "version", type: "shell"  do |s|
    s.inline = "echo -n \"#{$vm_version}\" > /home/vagrant/.vm_version"
  end

  # Primary Server
  config.vm.define "server0" do |server0|
    server0.vm.hostname = "krb0.local"

    server0.vm.provision "shell", inline: $configure_server_settings

    server0.vm.provision "shell", inline: "\
      echo 'Installing apt packages'; \
      export DEBIAN_FRONTEND=noninteractive; \
      apt-get update; \
      apt-get install -y #{$server_apt_packages}; \
      "

    server0.vm.provision "shell", inline: $configure_server_tools

    # Install Kerberos
    server0.vm.provision "krb", type: "shell" do |s|
      s.inline = "/home/vagrant/#{$project_name}/config/setup_kerberos.sh $@"
      s.args = [
        "krb0.local",
        "krb1.local",
      ]
    end

    # Install NFS
    server0.vm.provision "nfs", type: "shell" do |s|
      s.inline = "/home/vagrant/#{$project_name}/config/setup_nfs.sh $1"
      s.args = "krb0.local"
    end

    # VirtualBox Config
    server0.vm.provider "virtualbox" do |vb|
      # Display the VM name in the VirtualBox GUI
      vb.name = "#{$project_name}_server0"

      # Specify number of cores for VM.
      vb.cpus = $num_cpus

      # Specify amount of memory for VM [MB].
      vb.memory = $memory_size
    end
  end

  # Secondary Server
  config.vm.define "server1" do |server1|
    server1.vm.hostname = "krb1.local"

    server1.vm.provision "shell", inline: $configure_server_settings

    server1.vm.provision "shell", inline: "\
      echo 'Installing apt packages'; \
      export DEBIAN_FRONTEND=noninteractive; \
      apt-get update; \
      apt-get install -y #{$server_apt_packages}; \
      "

    server1.vm.provision "shell", inline: $configure_server_tools

    # Install Kerberos
    server1.vm.provision "krb", type: "shell" do |s|
      s.inline = "/home/vagrant/#{$project_name}/config/setup_kerberos.sh $@"
      s.args = [
        "krb0.local",
        "krb1.local",
      ]
    end

    # Install NFS
    server1.vm.provision "nfs", type: "shell" do |s|
      s.inline = "/home/vagrant/#{$project_name}/config/setup_nfs.sh $1"
      s.args = "krb0.local"
    end

    # VirtualBox Config
    server1.vm.provider "virtualbox" do |vb|
      # Display the VM name in the VirtualBox GUI
      vb.name = "#{$project_name}_server1"

      # Specify number of cores for VM.
      vb.cpus = $num_cpus

      # Specify amount of memory for VM [MB].
      vb.memory = $memory_size
    end
  end

  # Client
  config.vm.define "client" do |client|
    client.vm.hostname = "client.local"

    client.vm.provision "shell", inline: $configure_client_settings

    client.vm.provision "shell", inline: "\
      echo 'Installing apt packages'; \
      export DEBIAN_FRONTEND=noninteractive; \
      apt-get update; \
      apt-get install -y #{$client_apt_packages}; \
      "

    client.vm.provision "shell", inline: $configure_client_tools

    # Install Kerberos
    client.vm.provision "krb", type: "shell" do |s|
      s.inline = "/home/vagrant/#{$project_name}/config/setup_kerberos.sh $@"
      s.args = [
        "krb0.local",
        "krb1.local",
      ]
    end

    # Install NFS
    client.vm.provision "nfs", type: "shell" do |s|
      s.inline = "/home/vagrant/#{$project_name}/config/setup_nfs.sh $1"
      s.args = "krb0.local"
    end

    # VirtualBox Config
    client.vm.provider "virtualbox" do |vb|
      # Display the VM name in the VirtualBox GUI
      vb.name = "#{$project_name}_client"

      # Specify number of cores for VM.
      vb.cpus = $num_cpus

      # Specify amount of memory for VM [MB].
      vb.memory = $memory_size
    end
  end
end
