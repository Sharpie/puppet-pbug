# Manage debug configurations for Puppet Server
#
# This class can apply one or more debug configurations to the Puppet Server
# service.
#
# @see
#   https://www.yourkit.com/docs/java/help/startup_options.jsp
#   YourKit agent arugment string documentation
#
# @param enable_yourkit
#   Whether or not to attach the YourKit Java agent to Puppet Server.
# @param yourkit_args
#   Argument string passed to the YourKit Java agent.
class pbug::tk::puppetserver (
  Boolean $enable_yourkit = false,
  # TODO: Unwinding Java exceptions is very expensive and Puppet uses them for
  #       flow control in some spots, so we disable this by default. Otherwise,
  #       `puppet agent -t` can't complete in a reasonable amount of time
  #       if YourKit is tracking exceptions. However, this behavior was reduced
  #       in a recent Puppet version. Find that version and adjust
  #       the default accordingly.
  String  $yourkit_args = 'exceptions=disable',
){
  if $::facts['pe_server_version'] =~ NotUndef {
    $_service_name = 'pe-puppetserver'
  } else {
    $_service_name = 'puppetserver'
  }

  if $enable_yourkit {
    require '::pbug::install::yourkit'
    $_yourkit_ensure = 'present'
  } else {
    $_yourkit_ensure = 'absent'
  }

  pbug::java_agent { "${_service_name}: yourkit agent":
    ensure   => $_yourkit_ensure,
    type     => native,
    env_file => "/etc/sysconfig/${_service_name}",
    # FIXME: When pbug::install::yourkit allows configurable version numbers
    #        this will need to be updated.
    path     => '/opt/pbug/YourKit-JavaProfiler-2017.02/bin/linux-x86-64/libyjpagent.so',
    service  => Service[$_service_name],
    args     => $yourkit_args,
  }
}
