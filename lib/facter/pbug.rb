Facter.add(:pbug) do
  confine kernel: 'linux'

  setcode do
    result = {:versions => {}}

    if File.readable?('/opt/puppetlabs/puppet/VERSION')
      result[:versions][:puppet] = File.read('/opt/puppetlabs/puppet/VERSION').strip
    end

    if File.readable?('/opt/puppetlabs/server/pe_version')
      result[:versions][:pe] = File.read('/opt/puppetlabs/server/pe_version').strip
    end

    if File.readable?('/opt/puppetlabs/server/apps/puppetserver/ezbake.manifest')
      version = File.read('/opt/puppetlabs/server/apps/puppetserver/ezbake.manifest').match(/puppetlabs\/puppetserver "(.*)"/)

      result[:versions][:puppetserver] = version.captures.first unless version.nil?
    end

    if File.readable?('/opt/puppetlabs/server/apps/puppetdb/ezbake.manifest')
      version = File.read('/opt/puppetlabs/server/apps/puppetdb/ezbake.manifest').match(/puppetlabs\/puppetdb "(.*)"/)

      result[:versions][:puppetdb] = version.captures.first unless version.nil?
    end

    if File.readable?('/opt/puppetlabs/server/apps/orchestration-services/ezbake.manifest')
      version = File.read('/opt/puppetlabs/server/apps/orchestration-services/ezbake.manifest').match(/Release package:.*\((.*)\)/)

      result[:versions][:pe_orchestrator] = version.captures.first unless version.nil?
    end

    if File.readable?('/opt/puppetlabs/server/apps/console-services/ezbake.manifest')
      version = File.read('/opt/puppetlabs/server/apps/console-services/ezbake.manifest').match(/Release package:.*\((.*)\)/)

      result[:versions][:pe_console] = version.captures.first unless version.nil?
    end

    if Facter::Core::Execution.which("systemctl")
      version = Facter::Core::Execution.execute("systemctl --version").match(/systemd (\d+)/)

      result[:versions][:systemd] = version.captures.first unless version.nil?
    end

    result
  end
end
