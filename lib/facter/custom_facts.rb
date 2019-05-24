require 'cisco_node_utils'

class Facter::CiscoNexus::CustomFacts
  INTERFACE_PROPS = [:mtu, :speed, :duplex, :encapsulation_dot1q, :description, :ipv4_address]
  HSRP_PROPS = [:ipv4_vip, :preempt, :priority]

  def self.add_custom_facts(facts)
    # facts['my_custom_fact'] = 'my_custom_value'

    interfaces = {}
    Cisco::Interface.interfaces.each do |interface_name, nu_obj|
      begin
        # Some interfaces cannot or should not be managed by this type.
        # - NVE Interfaces (managed by cisco_vxlan_vtep type)
        next if interface_name =~ /nve/i
        state = {}
        # Call node_utils getter for each property
        INTERFACE_PROPS.each do |prop|
          state[prop] = nu_obj.send(prop)
        end

        interfaces[interface_name] = state
      end
    end
    
    hsrp_groups = {}
    Cisco::InterfaceHsrpGroup.groups.each do |group_name, nu_obj|
      begin
        state = {}
        # Call node_utils getter for each property
        HSRP_PROPS.each do |prop|
          state[prop] = nu_obj.send(prop)
        end

        hsrp_groups[group_name] = state
      end
    end

    facts['interfaces'] = interfaces
    facts['hsrp'] = hsrp_groups

  end
end
