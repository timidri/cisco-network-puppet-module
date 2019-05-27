require 'cisco_node_utils'

class Facter::CiscoNexus::CustomFacts
  PROPS = [:mtu, :speed, :duplex]
  HSRP_PROPS = [:ipv4_vip, :preempt, :priority]


  def self.add_custom_facts(facts)
    # facts['my_custom_fact'] = 'my_custom_value'

    # interfaces
    interfaces = {}
    Cisco::Interface.interfaces.each do |interface_name, nu_obj|
      # Some interfaces cannot or should not be managed by this type.
      # - NVE Interfaces (managed by cisco_vxlan_vtep type)
      next if interface_name =~ /nve/i
      state = {}
      # Call node_utils getter for each property
      PROPS.each do |prop|
        state[prop] = nu_obj.send(prop)
      end

      interfaces[interface_name] = state
    end

    # hsrp groups
    hsrp_groups = {}
    Cisco::InterfaceHsrpGroup.groups.each do |interface, groups|
      groups.each do |group, iptypes|
        iptypes.each do |iptype, nu_obj|
          state = {}
          # Call node_utils getter for each property
          HSRP_PROPS.each do |prop|
            state[prop] = nu_obj.send(prop)
          end

          hsrp_groups["#{interface} #{group} #{iptype}"] = state
        end
      end
    end

    # vrrp info
    Cisco::Environment.add_env('default',
      host:        config['address'],
      port:        config['port'],
      transport:   config['transport'],
      verify_mode: config['verify_mode'],
      username:    config['username'],
      password:    config['password'],
     )

    client = Cisco::Client.create()
    puts client.get(command: 'show vrrp')
    # set the facts
    facts['interfaces'] = interfaces
    facts['hsrp'] = hsrp_groups
  end
end