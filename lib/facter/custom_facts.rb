require 'cisco_node_utils'

class Facter::CiscoNexus::CustomFacts
  PROPS = [:mtu, :speed, :duplex]
  HSRP_PROPS = [:ipv4_vip, :preempt, :priority]


  def self.add_custom_facts(facts)
    # facts['my_custom_fact'] = 'my_custom_value'

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

    hsrp_groups = {}
    Cisco::InterfaceHsrpGroup.groups.each do |interface, groups|
      hsrp_groups[interface] = {}
      groups.each do |group, iptypes|
        hsrp_groups[interface][group] = {}
        iptypes.each do |iptype, nu_obj|
          state = {}
          # Call node_utils getter for each property
          HSRP_PROPS.each do |prop|
            state[prop] = nu_obj.send(prop)
          end

          hsrp_groups[interface][group][iptype] = state
        end
      end
    end

    facts['interfaces'] = interfaces
    facts['hsrp'] = hsrp_groups
  end
end