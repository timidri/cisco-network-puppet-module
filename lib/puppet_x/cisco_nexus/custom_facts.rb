require 'cisco_node_utils'
module Puppet::Provider::SnmpUser; end
require 'puppet/provider/snmp_user/cisco_nexus'

# implementing to_hash for successful duck typing
# in self.query_resources
class Puppet::ResourceApi::ResourceShim
  def to_hash
    @values
  end
end

# Proof of Concept custom fact implementation
class Facter::CiscoNexus::CustomFacts

  CLIENT = Cisco::Client.create

  # vrrp info, using command API since there is no supported vrrp resource
  # trying to support both vrrp and vrrpv3
  def self.vrrp_fact
    vrrp = []
    begin
      # require 'pry'; binding.pry
      vrrp_data = CLIENT.get(command: 'show vrrp', data_format: :nxapi_structured)
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
          vrrp_entry = {}
          vrrp_entry['interface'] = interface
          vrrp_entry['group'] = group
          interface_group.each do |key, value|
            # we don't need these keys in the properties
            next if ['sh_if_index', 'intf', 'sh_group_id', 'id'].include? key
            vrrp_entry[key.sub('sh_', '')] = value # remove the 'sh_' prefix
          end
          vrrp << vrrp_entry
        end
      end
    rescue
      # do nothing
    end
    vrrp
  end

  # listing active features
  def self.active_features_fact
    CLIENT.munge_to_array(CLIENT.get(command: 'show running | i ^feature', data_format: :cli))
  end

  # listing ospf neighbors
  # def self.ospf_neighbors_fact
  #   CLIENT.munge_to_array(CLIENT.get(command: 'show ip ospf neighbors', data_format: :cli))
  # end

  def self.ospf_neighbors_fact
    text = CLIENT.get(command: 'show ip ospf neighbors', data_format: :cli)
    return {} unless text # no neighbors
    lines = text.split("\n")
    line0_fields = lines[0].split
    pid = line0_fields[3]
    vrf = line0_fields[5]
    fact = {
      process_id: pid, 
      vrf: vrf,
    }
    
    neighbors = []
    lines[3..-1].each do |line|
      # The following line splits the string according to the supplied pattern.
      # We make sure to remove leading and trailing spaces for each element
      # An array element is created for every match. 
      # See https://www.rubydoc.info/stdlib/core/String:unpack
      neighbor_arr = line.unpack('A16A4A8A15A16A10').map{|s| s.strip}
      neighbor = {
        id: neighbor_arr[0],
        priority: neighbor_arr[1],
        state: neighbor_arr[2],
        uptime: neighbor_arr[3],
        address: neighbor_arr[4],
        interface: neighbor_arr[5]
      }
      neighbors << neighbor
    end
    fact['neighbors'] = neighbors
    fact
  end

  # query existing Puppet resources and output a hash
  # filter for keys we don't want to see
  def self.query_resources(type, include_attrs=[])
    Puppet::Resource.indirection.search(type, {} ).map do | resource |
      resource.to_hash.reject do |key|
        !(include_attrs.empty?) && !(include_attrs.include? key) || 
        ([:ensure, :loglevel, :provider].include? key)
      end 
    end
  end


  # adding the custom facts to the global facts hash
  def self.add_custom_facts(facts)

    facts['active_features'] = active_features_fact

    interface_props = [:interface, :mtu, :speed, :duplex, :encapsulation_dot1q, :description, :ipv4_address]
    facts['interfaces'] = query_resources('cisco_interface', interface_props)

    facts['snmp_users'] = query_resources('snmp_user')

    # facts depending on enabled features
    if Cisco::Feature::hsrp_enabled?
      hsrp_props = [:interface, :group, :iptype, :ipv4_vip, :preempt, :priority]
      facts['hsrp'] = query_resources('cisco_interface_hsrp_group', hsrp_props)
    end
    # querying for vrrp feature is not available
    # if Cisco::NodeUtil::config_get('feature', 'vrrp')
      facts['vrrp'] = vrrp_fact
    # end
    if Cisco::Feature::vtp_enabled?
      facts['vtp'] = query_resources('cisco_vtp')
    end
    if Cisco::Feature::tacacs_enabled?
      facts['tacacs_server'] = query_resources('cisco_tacacs_server')
    end
    if Cisco::Feature::bgp_enabled?
      facts['bgp_neighbor'] = query_resources('cisco_bgp_neighbor')
    end
    if Cisco::Feature::ospf_enabled?
      facts['ospf_neighbors'] = ospf_neighbors_fact
    end
  end
end
