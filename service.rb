#!/usr/bin/env ruby
require 'json'
require 'optparse'
require 'fileutils'
require 'etc'
require 'net/http'
require 'net/ftp'
require 'sys/proctable'
include Sys

class TelemetryGenerator
  def initialize
    @options = {}
    OptionParser.new do |opt|

      opt.banner = 'Usage: service.rb <activity_type> <target> [options]'
      opt.separator('Run without input to execute preprogrammed tests.')
      opt.separator('')
      opt.separator('Valid activity types: start_process, create_file, modify_file, remove_file, transmit_data')
      opt.separator('')
      opt.separator('Options:')
      opt.on('--data DATA', 'Data to transmit') { |o| @options[:data] = o }
      opt.on('--http-method METHOD', 'HTTP method to use') { |o| @options[:method] = o }
      opt.on('--args ARGS', 'Agument string to send to process') { |o| @options[:args] = o}
      opt.on_tail('-h', '--help', 'Show this message') do
        puts opt
        exit
      end
    end.parse!
    @activity_type = ARGV[0] if ARGV[0]
    @target = ARGV[1] if ARGV[1]
    @process = ProcTable.ps(pid: Process.pid)
  end

  def start_process(target = @target)
    @activity_type = 'start_process'
    @target = target
    if File.exists?(target) && File.executable?(target)
      pid = spawn([@target, @options[:args]].join(' '))
      @timestamp = Time.now
      @process = ProcTable.ps(pid: pid)
      Process.wait(pid)

      log_event
      @process = ProcTable.ps(pid: Process.pid)
    else
      puts 'Executable cannot be found'
    end
  end

  def create_file(target = @target, skip_log = false)
    @activity_type = 'create_file'
    @target = File.expand_path(target)
    dir_path = File.dirname(target)
    FileUtils.mkdir_p(dir_path) unless File.directory?(dir_path)
    file = File.new(target, 'w')
    @timestamp = Time.now
    file.close

    log_event unless skip_log
  end

  def modify_file(target = @target)
    @activity_type = 'modify_file'
    @target = File.expand_path(target)
    if File.exists?(target)
      file = File.new(target, 'w')
      file.write(@options[:data] || ' ')
      @timestamp = Time.now
      file.close

      log_event
    else
      puts 'File does not exist so it cannot be modified'
    end
  end

  def remove_file(target = @target)
    @activity_type = 'remove_file'
    @target = File.expand_path(target)
    if File.exists?(target)
      File.delete(target)
      @timestamp = Time.now

      log_event
    else
      puts 'File does not exist so it cannot be removed'
    end
  end
  
  def transmit_data(target = @target)
    @activity_type = 'transmit_data'
    @target = target
    uri = URI(@target)
    @protocol = uri.scheme

    Net::HTTP.start(uri.host, uri.port) do |http|
      case @options[:method].downcase
      when 'post'
        request = Net::HTTP::Post.new uri
        request['Content-Type'] = 'application/json'
        request.body = @options[:data]
      when 'put'
        request = Net::HTTP::Put.new uri
        request['Content-Type'] = 'application/json'
        request.body = @options[:data]
      when 'delete'
        request = Net::HTTP::Delete.new uri
      when 'get'
        request = Net::HTTP::Get.new uri
      end
      
      response = http.request(request)
      @request_data_size = request['Content-Length']
      @response_data_size = response['Content-Length']
      @source = "#{http.local_host}:#{http.local_port}"
      @destination = "#{http.address}:#{http.port}"
    end

    log_event
  end

  def log_event
    is_file_event = ['create_file', 'modify_file', 'remove_file'].include?(@activity_type)
    event_log = {
        timestamp: @timestamp,
        process_username: Etc.getpwuid(@process.uid).name,
        process_name: @process.name,
        process_commandline: @process.cmdline,
        process_id: @process.pid
    }
    event_log[:activity] = @activity_type if is_file_event
    event_log[:file_path] = @target if is_file_event
    event_log[:protocol] = @protocol if @protocol
    if @request_data_size || @response_data_size
      event_log[:data_size] = {} 
      event_log[:data_size][:request_data] = @request_data_size
      event_log[:data_size][:response_data] = @response_data_size
      event_log[:data_size][:total_data] = @request_data_size.to_i + @response_data_size.to_i
    end

    log_path = '/tmp/rc_take_home_logs/log.json'
    
    create_file(log_path, true) unless File.exists?(log_path)
    File.write(log_path, event_log.to_json, mode: 'a+')
    
  end
  
  def start
    case @activity_type
    when 'start_process'
      start_process(@target)
    when 'create_file'
      create_file(@target)
    when 'modify_file'
      modify_file(@target)
    when 'remove_file'
      remove_file(@target)
    when 'transmit_data'
      transmit_data(@target)
    else
      unless @target
        puts 'Running preprogrammed tests'

        start_process('./sample_files/executable')
        create_file('/tmp/rc_take_home/sample.jpg')
        modify_file('/tmp/rc_take_home/sample.jpg')
        remove_file('/tmp/rc_take_home/sample.jpg')
        @options[:method] = 'post'
        @options[:data] = '{"item": "book", "amount": "$35"}'
        transmit_data('http://example.com')
      else
        puts 'Please enter a valid command (run with -h to learn more)'
      end
    end
  end
end

validator = TelemetryGenerator.new
validator.start
