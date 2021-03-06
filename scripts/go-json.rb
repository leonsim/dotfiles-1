#!/usr/bin/env ruby
# encoding: utf-8

require 'time'
require 'json'

# Generate a go struct from JSON file
#
# Usage:
#
#   ./go-json.rb structName file.json
#
#   curl https://api.github.com | ~/dotfiles/scripts/go-json.rb api
#

def parse_json(text)
  JSON.parse(text)
rescue JSON::ParserError => e
  raise "Invalid JSON file content #{e}\n"
end

def parse_time(time_str)
  return nil if time_str !~ /\d{4}/

  %i(httpdate iso8601 rfc2822 rfc822).each do |m|
    begin
      return Time.send(m, time_str)
    rescue ArgumentError
      next nil
    end
  end
end

class StructWriter
  attr_reader :name, :fields, :content, :root, :type, :structs

  def initialize(name, content, root: false)
    @name = name
    @content = content
    @content = content.first if root && content.is_a?(Array)
    @root = root
    @fields = [] # this struct fields
    @structs = [] # inner structs, for nested json objects
  end

  def camelcase(str, lower = false)
    str = str.gsub(/([A-Z])/, '_\\1') # convert snakeCase
             .split('_')
             .map(&:capitalize)
             .map { |w| w == 'Id' ? 'ID' : w }
             .map { |w| w == 'Ids' ? 'IDs' : w }
             .join

    str[0] = str[0].downcase if lower
    str
  end

  def titlelize(str)
    str.gsub(/([A-Z][a-z])/, ' \1').strip.downcase
  end

  def parse_struct(k, data)
    field = camelcase(k)
    attrs = ',omitempty' if k == 'id'

    if data.is_a?(Array)
      field = field.chop if field[-1] == 's' # assume Array field has suffix "s"
      prefix = '[]'
      data = data.first
    end

    type = data.is_a?(Hash) ? to_struct(field, data) : to_gotype(data)
    fields << "#{camelcase(k)} #{prefix}#{type} `json:\"#{k}#{attrs}\"`"
  end

  def to_struct(field, data)
    struct_name = "#{name}#{field}"
    structs << StructWriter.new(struct_name, data)
    "*#{struct_name}"
  end

  def to_gotype(data)
    case data
    when Integer, Fixnum then 'int64'
    when Float then 'float64'
    when TrueClass, FalseClass then 'bool'
    when String then parse_time(data) ? 'time.Time' : 'string'
    else 'null'
    end
  end

  def write
    raise "Invalid data: #{@content}" unless @content.is_a?(Hash)

    @content.each { |k, v| parse_struct(k, v) }

    <<-EOS.gsub(/^$\n\n+/, "\n")
// #{name} defines a struct for #{titlelize(name)}
type #{name} struct {
    #{fields.join("\n    ")}
}

#{structs.map(&:write).join('')}
    EOS
  end
end

# ARGV Logic
if ($stdin.tty? && ARGV.length < 2) || (ARGV.length < 1)
  $stderr << "Usage: ./go-json.rb StructName file.json\n"
  exit(1)
end

begin
  struct_name = ARGV.shift
  content = parse_json(ARGF.read)
  writer = StructWriter.new(struct_name, content, root: true)

  $stdout << writer.write
rescue Exception => e
  $stderr << "Error: #{e}\n"
  exit(2)
end
