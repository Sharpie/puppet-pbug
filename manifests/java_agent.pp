# Manage java agents loaded by a JVM service
#
# This defined type manages the presence of Java agents that may be added
# to JVM processes. These are JAR files or shared object libraries that
# are commonly used to add instrumentation or monitoring functionality to
# Java services. Instances of this type operate by using an `ini_subsetting`
# resource to add or remove a CLI argument from an environment variable
# defining the Java CLI for the service in files such as those found under
# `/etc/sysconfig` or `/etc/default`.
#
# @see
#   https://docs.oracle.com/javase/8/docs/api/java/lang/instrument/package-summary.html
#   Java agent documentation
#
# @example
#   pbug::java_agent { 'async-profiler agent for someservice':
#     ensure   => present,
#     type     => 'native',
#     env_file => '/etc/sysconfig/someservice',
#     path     => '/opt/async-profiler/build/libasyncProfiler.so',
#     service  => Service['someservice'],
#     env_var  => 'JAVA_ARGS',
#     args     => 'start,svg,file=/tmp/profile.svg',
#   }
#
# @param ensure
#   Whether to add or remove the agent from the service. **Required.**
# @param type
#   Set to `java` if the agent is a JAR file or `native` if the agent is
#   a shared object library. **Required.**
# @param env_file
#   A file, such as those found under `/etc/sysconfig` or `/etc/default`, that
#   holds environment variables that define the CLI args passed to the service.
#   **Required.**
# @param path
#   The path to the JAR or shared object libarary that contains the agent code.
#   **Required.**
# @param service
#   A Puppet resource to be notified if the agent configuration changes.
#   Commonly a `Service` or `Exec` resource that will restart the Java service.
# @param env_var
#   The name of an environment variable in the `env_file` that holds CLI
#   arguments for the service.
# @param args
#   A string of additional arguments to be passed to the Java agent.
define pbug::java_agent (
  Enum['present', 'absent'] $ensure,
  Enum['java', 'native']    $type,
  String                    $env_file,
  String                    $path,
  Optional[Type[Resource]]  $service = undef,
  Optional[String]          $env_var = 'JAVA_ARGS',
  Optional[String]          $args = undef,
){
  $_agent_flag = $type ? {
    'java'   => '-javaagent',
    'native' => '-agentpath',
  }

  ini_subsetting { $title:
    ensure            => $ensure,
    path              => $env_file,
    key_val_separator => '=',
    section           => '',
    setting           => $env_var,
    quote_char        => '"',
    subsetting        => "${_agent_flag}:${path}=",
    value             => $args,
  }

  if $service =~ NotUndef {
    Ini_subsetting[$title] ~> $service
  }
}
