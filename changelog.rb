#!/usr/bin/env ruby

require 'rubygems'
require 'set'
require 'net/http'
require "net/https"
require 'json'
require 'pathname'

config_file = "#{ENV['HOME']}/.changelog"

if Pathname.new(config_file).file?
  load config_file
end

if not $assembla_api_key or not $assmebla_api_secret
  puts "Put a file '.changelog' with the following content in your home folder:"
  puts "------"
  puts "$assembla_api_key = 'your_api_key'"
  puts "$assmebla_api_secret = 'your_api_secret'"
  puts "------"
  puts
  puts "You can find your Assembla API Key on your Profile page."
  exit 1
end

if ARGV.length < 2
  puts "usage: changelog [space_id] [git-options]+"
  exit 1
end

$assembla_space = ARGV[0]
$git_log_options = ARGV[1..-1].join(" ")

def get_assembla_ticket_info(ticket_no)
  uri = URI("https://api.assembla.com/v1/spaces/#{$assembla_space}/tickets/#{ticket_no}.json")

  req = Net::HTTP::Get.new(uri.request_uri)
  req['X-Api-Key'] = $assembla_api_key
  req['X-Api-Secret'] = $assmebla_api_secret

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  res = http.start { |h| h.request(req) }
  json = JSON.parse(res.body)

  if json['error'] == 'invalid_auth'
    puts "ERROR: #{json['error_description']}"
    exit 2
  end

  json
end

tickets = Set.new

IO.popen("git log --oneline --no-merges #{$git_log_options}") { |f|
  commits = f.readlines
  commits.each { |commit|
    if commit =~ /#(\d+)/
      tickets.add(Regexp.last_match(1).to_i)
    end
  }
}

tickets.sort.each { |x|
  ticket = get_assembla_ticket_info(x)
  puts "##{x} - #{ticket['summary']} (#{ticket['status']})"
}