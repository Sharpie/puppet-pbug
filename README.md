# PBUG

This project contains a Puppet module that automates the application of
debugging configurations to Puppet and Puppet Enterprise services. Examples
of such configurations include:

  - Downloading and configuring [Java agent] libraries that add monitoring,
    profiling, or debugging capabilities.

See the [usage section](#usage) for more details.

[Java agent]: https://docs.oracle.com/javase/8/docs/api/java/lang/instrument/package-summary.html

## Requirements

This module is compatible with Puppet 4.10 and newer, which translates to
PE 2016.4 and newer. Older versions of PE may work, but have not been tested.


## Usage

### pbug::tk::puppetserver

This class manages debug configurations for the Puppet Server service. The
following configurations are available:

  - `enable_yourkit`: Whether to enable the YourKit Java agent.
  - `yourkit_args`: Arguments that modify the [behavior of the YourKit agent](https://www.yourkit.com/docs/java/help/startup_options.jsp).

This class assumes that the `Service['pe-puppetserver']` or `Service['puppetserver']`
resources are managed by other manifests.
