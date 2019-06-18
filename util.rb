require 'json'
module JSON
  def self.is_json?(foo)
    begin
      return false unless foo.is_a?(String)
      self.parse(foo).all?
    rescue self::ParserError
      false
    end
  end
end

class User
  attr_reader :name

  # @param [String] name
  def initialize(client, name, mod = false, admin = false, staff = false)
    @client = client
    @name = name
    @mod = mod
    @admin = admin
    @staff = staff
    @ignored = ignored?
  end

  # Check if a user has the given privilege. Privileges cascade, so:
  #    - +:mod+ returns true if user is +:dev+, +:staff+, +:admin+, or +:mod+
  #    - +:admin+ returns true if user is +:dev+, +:staff+, or +:admin+
  #    - +:staff+ returns true if user is +:dev+ or +:staff+
  #    - +:dev+ returns true if and only if <tt>@name == 'Sactage'</tt>
  # @param [Symbol] right
  # @return [TrueClass, FalseClass]
  def is?(right)
    case right
      when :mod
        @mod or @admin or @staff or is? :dev
      when :admin
        @admin or @staff or is? :dev
      when :staff
        @staff or is? :dev
      when :dev
        @name.eql?('KockaAdmiralac') or (!@client.config['dev'].nil? and @name.eql?(@client.config['dev']))
      else
        false
    end
  end

  # @return [String] The user's name with underscores instead of spaces
  def log_name
    @name.gsub(' ', '_')
  end

  # Check if the user is ignored
  # @return [TrueClass, FalseClass]
  def ignored?
    return @ignored unless @ignored.nil?
    if File.exists? 'ignore.yml'
      YAML::load_file('ignore.yml')['users'].include? @name
    else
      File.open('ignore.yml', 'w+') {|f| f.write({'users' => []}.to_yaml)}
      false
    end
  end

  # Ignore the user
  def ignore
    return if is? :dev
    # @type [Hash] ignorefile
    if File.exists? 'ignore.yml'
      ignorefile = YAML::load_file('ignore.yml')
    else
      ignorefile = {'users' => []}
    end
    ignorefile['users'] << @name
    File.open('ignore.yml', 'w+') {|f| f.write(ignorefile.to_yaml)}
    @ignored = true
  end

  # Unignore the user
  def unignore
    if File.exists? 'ignore.yml'
      ignorefile = YAML::load_file('ignore.yml')
    else
      ignorefile = {'users' => []}
    end
    ignorefile['users'].delete(@name)
    File.open('ignore.yml', 'w+') {|f| f.write(ignorefile.to_yaml)}
    @ignored = false
  end
end

module Util
  LOG_TS_FORMAT = '[%Y-%m-%d %H:%M:%S]'

  # @return [String] Log timestamp string of current time
  def self.ts
    Time.now.utc.strftime LOG_TS_FORMAT
  end

  # Format the given string into a socket.io-readable format
  # @param [String] message
  # @return [String]
  def self.format_message(message)
    message.size.to_s + ':' + message
  end
end

class Time
  # @return [Fixnum] The time since the UNIX epoch in micro-seconds
  def to_ms
    (self.to_f * 1000.0).to_i
  end
end
