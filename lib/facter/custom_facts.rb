require 'cisco_node_utils'

class Facter::CiscoNexus::CustomFacts
  PROPS = [:mtu, :speed, :duplex]

  def self.add_custom_facts(facts)
    facts['my_custom_fact'] = 'my_custom_value'

    interfaces = {}
    Cisco::Interface.interfaces.each do |interface_name, nu_obj|
      begin
          # Some interfaces cannot or should not be managed by this type.
          # - NVE Interfaces (managed by cisco_vxlan_vtep type)
          next if interface_name =~ /nve/i
          state = {}
          # Call node_utils getter for each property
          PROPS.each do |prop|
            state[prop] = nu_obj.send(prop)
          end

          interfaces << { interface_name: state }
        end
    end
    facts['interfaces'] = interfaces
  end
end
