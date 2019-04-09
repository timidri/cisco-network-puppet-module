class Facter::CiscoNexus::CustomFacts

  def self.add_custom_facts(facts)

    facts['my_custom_fact'] = 'my_custom_value'

  end
end