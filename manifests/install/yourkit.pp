# Manage installation of the YourKit Java agent
#
# This class downloads and unpacks the YourKit Java agent bundle to
# the `/opt/pbug` directory.
#
# @see
#   https://www.yourkit.com/docs/java/help/agent.jsp
#   YourKit Java agent documentation
#
# @todo Make version number configurable.
#
# @param ensure
#   Whether to add or remove the YourKit agent files from the node.
class pbug::install::yourkit (
  Enum['present', 'absent'] $ensure = 'present',
){
  # NOTE: Exec used here to avoid duplicate resource clashes from multiple
  #       classes ensuring the presence of this directory.
  exec { 'yourkit: ensure /opt/pbug directory existence':
    command => 'mkdir -m 0755 -p /opt/pbug',
    creates => '/opt/pbug',
    path    => $::facts['path'],
  }

  # FIXME: Hardcoded to version 2017.02-b75 for $reasons. Allow passing a
  #        version number to the class.
  if $ensure == 'present' {
    archive { '/tmp/YourKit-JavaProfiler-2017.02-b75.zip':
      ensure       => present,
      extract      => true,
      extract_path => '/opt/pbug',
      source       => 'https://www.yourkit.com/download/YourKit-JavaProfiler-2017.02-b75.zip',
      creates      => '/opt/pbug/YourKit-JavaProfiler-2017.02',
      cleanup      => true,
    }
  } else {
    file { '/opt/pbug/YourKit-JavaProfiler-2017.02':
      ensure => absent,
      force  => true,
    }
  }
}
