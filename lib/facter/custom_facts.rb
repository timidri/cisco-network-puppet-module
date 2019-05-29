require 'cisco_node_utils'

class Facter::CiscoNexus::CustomFacts
  INTERFACE_PROPS = [:mtu, :speed, :duplex]
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
      INTERFACE_PROPS.each do |prop|
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
    # trying to support both vrrp and vrrpv3
    vrrp_fact = {}
    client = Cisco::Client.create
    begin
      # require 'pry'; binding.pry
      vrrp_data = client.get(command: 'show vrrp', data_format: :nxapi_structured)
      vrrp_table = vrrp_data['TABLE_vrrp_group'] || vrrp_data['TABLE_grp']
      if vrrp_table.respond_to?(:to_hash) # it's a Hash, not an Array
        vrrp_table = [vrrp_table] # we convert to Array to simplify code
      end
      vrrp_table.each do |row_group|
        row_data = row_group['ROW_vrrp_group'] || row_group['ROW_grp']
        if row_data.respond_to?(:to_hash) # it's a Hash, not an Array
          row_data = [row_data] # we convert to Array to simplify code
        end
        row_data.each do |interface_group|
          interface = interface_group['sh_if_index'] || interface_group['intf']
          group = interface_group['sh_group_id'] || interface_group['id']
          vrrp_fact["#{interface} #{group}"] = {}
          interface_group.each do |key, value|
            # we don't need these keys in the properties
            next if ['sh_if_index', 'intf', 'sh_group_id', 'id'].include? key
            vrrp_fact["#{interface} #{group}"][key.sub('sh_', '')] = value # remove the 'sh_' prefix
          end
        end
      end
    rescue
      # do nothing
    end
    # set the facts
    facts['interfaces'] = interfaces
    facts['hsrp'] = hsrp_groups
    facts['vrrp'] = vrrp_fact
  end
end
