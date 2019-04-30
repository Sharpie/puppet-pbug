#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'optparse'
require 'rubygems/requirement'
require 'socket'
require 'time'
require 'uri'

module PBug
# Tools for importing Puppet metrics into time series databases
module ImportMetrics
  VERSION = '0.0.1'
  REQUIRED_RUBY_VERSION = Gem::Requirement.new('>= 2.1')

  class NetworkOutput
    # TODO: Support HTTPS.
    def initialize(host_url)
      @url = URI.parse(host_url) unless host_url.is_a?(URI)
      open
    end

    def open
      return if @output

      @output = case @url.scheme
                when 'tcp'
                  TCPSocket.new(@url.host, @url.port)
                when 'http'
                  http = Net::HTTP.new(@url.hostname, @url.port)
                  http.keep_alive_timeout = 20
                  http.start

                  http
                end
    end

    def write(str, timeout = 1)
      case @url.scheme
      when 'tcp'
        begin
          @output.write(str)
        rescue Errno::EPIPE, Errno::EHOSTUNREACH, Errno::ECONNREFUSED
          close
          STDERR.puts "WARNING: write to #{@host} failed; sleeping for #{timeout} seconds and retrying..."
          sleep timeout
          open
          write(str, timeout * 2)
        end
      when 'http'
        request = Net::HTTP::Post.new(@url)
        request['Connection'] = 'keep-alive'
        response = @output.request(request, str)

        STDERR.puts "POST: #{@url} #{response.code}"
      end
    end

    def close
      case @url.scheme
      when 'tcp'
        @output.close
      when 'http'
        @output.finish
      end
    ensure
      @output = nil
    end
  end

  class CLI
    ARG_SPECS = [['--pattern PATTERN',
                  'Glob pattern of files to load.',
                  'Must be provided if no files are passed.'],
                 ['--host HOST',
                  'Hostname or IP address to send output to.',
                  'If not specified, output goes to STDOUT.'],
                 ['--port PORT',
                  Integer,
                  'Port number to send output to.'],
                 ['--convert-to FORMAT',
                  'Output format to convert to. One of:',
                  '  graphite (default)',
                  '  influxdb'],
                 ['--server-tag SERVER_NAME',
                  'Server hostname to associate with parsed metrics.'],
                 ['--influx-db DATABASE_NAME',
                  'Name of InfluxDB database to send metrics to.',
                  'Requires "--host" and "--convert-to influxdb".']]

    def initialize(argv = [])
      @data_files = []
      @action = :parse_data
      @options = {convert_to: 'graphite'}

      store_option = lambda do |hash, key, val|
        hash[key] = val
      end

      @optparser = OptionParser.new do |parser|
        parser.banner = "Usage: import_metrics.rb [options] [puppet_metrics_collector_output.json] [...]"

        parser.on_tail('-h', '--help', 'Show help') do
          @action = :show_help
        end

        parser.on_tail('--debug', 'Enable backtraces from errors.') do
          @options[:debug] = true
        end

        parser.on_tail('--version', 'Show version') do
          @action = :show_version
        end
      end

      ARG_SPECS.each do |spec|
        # TODO: Yell if ARG_SPECS entry contains no --long-flag.
        long_flag = spec.find {|e| e.start_with?('--')}.split(' ').first
        option_name = long_flag.sub(/\A-+(?:\[no-\])?/, '').gsub('-', '_').to_sym

        @optparser.on(store_option.curry[@options][option_name], *spec)
      end

      # Now that sub-parsers have been defined for each option, use them
      # to parse PT_ environment variables that are set if this script is
      # invoked as a task.
      @optparser.top.list.each do |option|
        option_name = option.switch_name.gsub('-', '_')
        task_var = "PT_#{option_name}"

        next unless ENV.has_key?(task_var)

        @options[option_name.to_sym] = option.parse(ENV[task_var], []).last
      end

      args = argv.dup
      @optparser.parse!(args)

      # parse! consumes all --flags and their arguments leaving
      # file names behind.
      @data_files += args
    end

    # Parse files and print results to STDERR
    #
    # @return [Integer] An integer representing process exit code that can be
    #   set by the caller.
    def run
      case @action
      when :show_help
        $stdout.puts(@optparser.help)
        return 0
      when :show_version
        $stdout.puts(VERSION)
        return 0
      end

      if not REQUIRED_RUBY_VERSION.satisfied_by?(Gem::Version.new(RUBY_VERSION))
        $stderr.puts("import_metrics.rb requires Ruby #{REQUIRED_RUBY_VERSION}")
        return 1
      end

      if @options[:host]
        url = case @options[:convert_to]
              when 'influxdb'
                raise ArgumentError, "--influx-db must be passsed along with --host" unless @options[:influx_db]
                port = @options[:port] || "8086"
                "http://#{@options[:host]}:#{port}/write?db=#{@options[:influx_db]}&precision=s"
              else
                port = @options[:port] || "2003"
                "tcp://#{@options[:host]}:#{port}"
              end

        @net_output = NetworkOutput.new(url)
      end

      require 'pp'
      PP.pp(@options, $stdout)

      @data_files += Dir.glob(@options[:pattern]) if @options[:pattern]

      # TODO: Exit with help message if data_files empty.

      if @data_files.empty?
        $stderr.puts("ERROR: No data files to parse.")
        $stderr.puts(@optparser.help)
        return 1
      end

      @data_files.each do |filename|
        begin
          converted_data = parse_file(filename)

          if @options[:host]
            @net_output.write(converted_data)
          else
            STDOUT.write(converted_data)
          end
        rescue => e
          STDERR.puts "ERROR: #{filename}: #{e.message}"
        end
      end

      return 0
    rescue => e
      message = if @options[:debug]
                  ["ERROR #{e.class}: #{e.message}",
                   e.backtrace].join("\n\t")
                else
                  "ERROR #{e.class}: #{e.message}"
                end

      $stderr.puts(message)
      return 1
    ensure
      @net_output.close if @options[:host]
    end

    def parse_file(filename)
      data = JSON.parse(File.read(filename))

      # Newer versions of the log tool insert a timestamp field into the JSON.
      if data['timestamp']
        timestamp = Time.parse(data.delete('timestamp'))
        parent_key = nil
      else
        timestamp = get_timestamp(filename)
        # The only data supported in the older log tool comes from puppetserver.
        parent_key = 'servers.' + get_hoststr(filename) + '.puppetserver'
      end

      case @options[:convert_to]
      when 'influxdb'
        influx_metrics(data, timestamp, parent_key).join("\n")
      else
        metrics(data, timestamp, parent_key).map do |item|
          item.split('\n')
        end.flatten.join("\r\n")
      end
    end

    def get_timestamp(str)
      # Example filename: nzxppc5047.nndc.kp.org-11_29_16_13:00.json
      timestr = str.match(/(\d\d)_(\d\d)_(\d\d)_(\d\d:\d\d)\.json$/) || raise("Unable to parse timestame from #{str}")
      yyyy = timestr[3].sub(/.*_(\d\d)$/, '20\1')
      mm = timestr[1]
      dd = timestr[2]
      hhmm = timestr[4]
      Time.parse("#{yyyy}-#{mm}-#{dd} #{hhmm}")
    end

    def get_hoststr(str)
      # Example filename: patched.nzxppc5047.nndc.kp.org-11_29_16_13:00.json
      str.match(/(patched\.)?([^\/]*)-(\d\d_){3}\d\d:\d\d\.json$/)[2].gsub('.', '-')
    end

    def safe_name(value)
      value.sub(/^[^0-9a-z_-]/i, '').gsub(/[^0-9a-z_-]/i, '_').gsub(/__/, '_').sub(/_*$/, '')
    end

    def array_cipher
      @array_cipher ||= {
        'http-metrics' => {
          'pkey' => 'route-id',
          'keys' => {
            'puppet-v3-catalog-/*/' => 'catalog',
            'puppet-v3-node-/*/'    => 'node',
            'puppet-v3-report-/*/'  => 'report',
            'puppet-v3-file_metadata-/*/'  => 'file-metadata',
            'puppet-v3-file_metadatas-/*/' => 'file-metadatas'
          }
        },
        'function-metrics' => {
          'pkey' => 'function',
          'keys' => :all
        },
        'catalog-metrics' => {
          'pkey' => 'metric',
          'keys' => :all
        },
        'resource-metrics' => {
          'pkey' => 'resource',
          'keys' => :all
        },
      }
    end

    def error_name(str)
      if str["mbean"]
        str[/'[^']+'([^']+)'/,1]
      else
        str
      end
    end

    def return_tag(a, n)
      if a[n].is_a? String
        return a[n]
      else
        if n > -1
          return_tag(a, n-1)
        else return "none"
      end
    end
    end

    def metrics(data, timestamp, parent_key = nil)
      data.collect do |key, value|
        current_key = [parent_key, safe_name(key)].compact.join('.')
        case value
        when Hash
          metrics(value, timestamp, current_key)
        when Array
          cipher = array_cipher[key]
          if cipher
            value.map do |elem|
              pkey_value = elem.delete(cipher['pkey'])
              elem.map do |k,v|
                if cipher['keys'] == :all || subkey = cipher['keys'][pkey_value]
                  subkey ||= pkey_value
                  "#{current_key}.#{safe_name(subkey)}.#{safe_name(k)} #{v} #{timestamp.to_i}"
                else
                  nil
                end
              end.compact
            end.flatten.compact.join("\n")
          elsif key == 'error'
            value.map do |elem|
              ekey = error_name(elem)
              "#{current_key}.#{safe_name(ekey)} 1 #{timestamp.to_i}"
            end.compact
          else
            nil
          end
        else
          "#{current_key} #{value} #{timestamp.to_i}"
        end
      end.flatten.compact
    end

    def remove_trailing_comma(str)
        str.nil? ? nil : str.chomp(",")
    end

    def influx_tag_parser(tag)
      delete_set = ["status", "metrics", "routes", "status-service", "experimental", "app", "max", "min", "used", "init", "committed", "aggregate", "mean", "std-dev", "count", "total", "1", "5", "15"]
      tag = tag - delete_set
      tag_set = nil

      if tag.include? "servers"
        n = tag.index "servers"
        server_name = @options[:server_tag] || tag[n.to_i + 1]
        tag_set = "server=#{server_name},"
        tag.delete_at(tag.index("servers")+1)
        tag.delete("servers")
      end

      if tag.include? "orchestrator"
        tag_set = "#{tag_set}service=orchestrator,"
        tag.delete("orchestrator")
      end

      if tag.include? "puppet_server"
        tag_set = "#{tag_set}service=puppet_server,"
        tag.delete("puppet_server")
      end

      if tag.include? "puppetdb"
        tag_set = "#{tag_set}service=puppetdb,"
        tag.delete("puppetdb")
      end

      if tag.include? "gc-stats"
        n = tag.index "gc-stats"
        gcstats_name = tag[n.to_i + 1]
        tag_set = "#{tag_set}gc-stats=#{gcstats_name},"
        tag.delete_at(tag.index("gc-stats")+1)
        tag.delete("gc-stats")
      end

      if tag.include? "broker-service"
        n = tag.index "broker-service"
        brokerservice_name = tag[n.to_i + 1]
        tag_set = "#{tag_set}broker-service_name=#{brokerservice_name},"
        tag.delete_at(tag.index("broker-service")+1)
        tag.delete("broker-service")
      end

      if tag.include?('Queue')
        n = tag.index('Queue')
        amq_destination_name = tag[n + 1]
        tag_set = "#{tag_set}amq-destination-type=Queue,amq-destination-name=#{amq_destination_name}"

        tag.slice!(n, 2)
      end

      if tag.include?('Topic')
        n = tag.index('Topic')
        amq_destination_name = tag[n + 1]
        tag_set = "#{tag_set}amq-destination-type=Topic,amq-destination-name=#{amq_destination_name}"

        tag.slice!(n, 2)
      end

      if tag.length > 1
        measurement = tag.compact.join('.')
        tag_set = "#{measurement},#{tag_set}"
      elsif tag.length == 1
        measurement = tag[0]
        tag_set = "#{measurement},#{tag_set}"
      end

      tag_set = remove_trailing_comma(tag_set)
      return tag_set
    end

    def influx_metrics(data, timestamp, parent_key = nil)
      data.collect do |key, value|
        current_key = [parent_key, safe_name(key)].compact.join('.')
        case value
        when Hash
          influx_metrics(value, timestamp, current_key)
        when Numeric
          temp_key = current_key.split(".")
          field_key = return_tag(temp_key, temp_key.length)
          if field_key.eql? "none"
            break
          end
          field_value = value
          tag_set = influx_tag_parser(temp_key)
          "#{tag_set} #{field_key}=#{field_value} #{timestamp.to_i}"
        when Array
          # Puppet Profiler metric.
          pp_metric = case current_key
                      when /resource-metrics\Z/
                        "resource"
                      when /function-metrics\Z/
                        "function"
                      when /catalog-metrics\Z/, /puppetdb-metrics\Z/
                        "metric"
                      when /http-metrics\Z/
                        "route-id"
                      when /borrowed-instances\Z/
                        longest_borrow = value.map {|h| h['duration-millis']}.sort.last
                        tag_set = influx_tag_parser(current_key.split('.'))

                        next "#{tag_set} longest-borrow=#{longest_borrow} #{timestamp.to_i}"
                      else
                        # Skip all other array valued metrics.
                        next
                      end

          temp_key = current_key.split(".")
          tag_set = influx_tag_parser(temp_key)

          value.map do |metrics|
            working_set = metrics.dup
            entry_name = working_set.delete(pp_metric)
            next if entry_name.nil?

            # Strip characters reserved by InfluxDB.
            entry_name.gsub(/\s,=/, '')
            leader = "#{tag_set},name=#{entry_name}"

            measurements = working_set.map {|k,v| [k,v].join("=")}.join(',')

            "#{leader} #{measurements} #{timestamp.to_i}"
          end
        else
          nil
        end
      end.flatten.compact
    end
  end
end
end


# Entrypoint for when this file is executed directly.
if File.expand_path(__FILE__) == File.expand_path($PROGRAM_NAME)
  exit_code = PBug::ImportMetrics::CLI.new(ARGV).run
  exit exit_code
end
