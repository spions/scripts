require 'facter'

# vmware installed?
Facter.add("vmtools_installed") do
  setcode do
    File.exists?('/usr/bin/vmware-toolbox-cmd')
  end
end

# vmware-running?
Facter.add("vmtools_version") do
  setcode do
    Facter::Util::Resolution::exec('/usr/bin/vmware-toolbox-cmd -v')
  end
end
