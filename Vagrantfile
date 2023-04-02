# vi: set ft=ruby ts=2 :

require 'yaml'

VAGRANTFILE_API_VERSION = "2"

# check for required plugins
_required_plugins_list = %w{vagrant-libvirt}
exit(1) unless _required_plugins_list.all? do |plugin|
  Vagrant.has_plugin?(plugin) || (
    STDERR.puts "Required plugin '#{plugin}' is missing; please install using:"
    STDERR.puts "  % vagrant plugin install #{plugin}"
    false
  )
end

# ensure libvirt is the default provider in case the vagrant box config
# doesn't specify it
ENV['VAGRANT_DEFAULT_PROVIDER'] = "libvirt"

@root_dir = File.dirname(File.expand_path(__FILE__))
@settings = YAML.load_file(File.join(@root_dir, "settings.yml"))

dhcp_server_ip = @settings['harvester_network_config']['dhcp_server']['ip']
cpu_count = @settings['harvester_node_config']['cpu']
memory_size = @settings['harvester_node_config']['memory']
disk_size = @settings['harvester_node_config']['disk_size']
cluster_create_node_number = @settings['harvester_cluster_create_nodes']
name_suffix = @settings['harvester_cluster']['name_suffix']
network_name = "harvester-#{name_suffix}"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  # continerd is taking more than 60 seconds to shutdown in SUSE platforms
  # so increase the timeout to 120 seconds
  config.vm.graceful_halt_timeout = 120
  vm_name = "pxe-server-#{name_suffix}"
  config.vm.define vm_name do |pxe_server|
    pxe_server.vm.box = 'generic/debian10'
    pxe_server.vm.hostname = 'pxe-server'
    pxe_server.vm.network 'private_network',
      ip: "#{dhcp_server_ip}",
      libvirt__network_name: "#{network_name}",
      # don't enable DHCP as this node will have it's now DHCP server for iPXE
      # boot
      libvirt__dhcp_enabled: false

    pxe_server.vm.provider :libvirt do |libvirt|
      libvirt.cpu_mode = 'host-passthrough'
      libvirt.memory = '1024'
      libvirt.cpus = '1'
    end

    # Use ansible to install server
    pxe_server.vm.provision :ansible do |ansible|
      ansible.playbook = 'ansible/setup_pxe_server.yml'
      ansible.extra_vars = {
        settings: @settings
      }
    end
  end

  (1..cluster_create_node_number).each do |node_number|
    vm_name = "harvester-#{name_suffix}-#{node_number}"
    config.vm.define vm_name, autostart: true do |harvester_node|
      harvester_node.vm.hostname = "#{vm_name}"
      harvester_node.vm.network 'private_network',
        libvirt__network_name: "#{network_name}",
        mac: @settings['harvester_network_config']['cluster'][node_number-1]['mac']
      harvester_node.vm.network 'private_network',
        libvirt__network_name: "#{network_name}",
        mac: @settings['harvester_network_config']['cluster'][node_number-1]['mac_second']

      harvester_node.vm.provider :libvirt do |libvirt|
        libvirt.cpu_mode = 'host-passthrough'
        libvirt.memory = memory_size
        libvirt.cpus = cpu_count
        libvirt.storage :file,
          size: disk_size,
          type: 'qcow2',
          bus: 'virtio',
          device: 'vda'
        libvirt.storage :file,
          size: '10G',
          type: 'qcow2',
          bus: 'virtio',
          device: 'vdb'
        boot_network = {'network' => "#{network_name}"}
        libvirt.boot 'hd'
        libvirt.boot boot_network
        # NOTE: default to UEFI boot. Comment this out for legacy BIOS.
        libvirt.loader = '/usr/share/qemu/OVMF.fd'
        libvirt.nic_model_type = 'e1000'
      end
    end
  end
end
