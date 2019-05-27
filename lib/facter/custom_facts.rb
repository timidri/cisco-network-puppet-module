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
    client = Cisco::Client.create()
    vrrp_data = client.get(command: 'show vrrp', data_format: :nxapi_structured)
    puts vrrp_data
    vrrp_fact = {}
    vrrp_table = vrrp_data['TABLE_vrrp_group']
    vrrp_table.each do |row|
      row_data = row['ROW_vrrp_group']
      group_name = row_data['sh_if_index']
      vrrp_fact[group_name] = {}
      row_data.each do |key, value|
        vrrp_fact[group_name][key] = value
      end
    # set the facts
    facts['interfaces'] = interfaces
    facts['hsrp'] = hsrp_groups
    facts['vrrp'] = vrrp_fact
  end
end