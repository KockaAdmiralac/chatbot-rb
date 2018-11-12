require_relative '../plugin'

class Chatbot::AntiSpam
  include Chatbot::Plugin

  match /(.*)/, :method => :check, :use_prefix => false

  # @param [Chatbot::Client] client
  def initialize(client)
    super(client)
    @config = client.config['antispam'] || {}
    @words = @config['words'] || []
    @warn = @config['warn'] || 1
    @kick = @config['kick'] || 2
    @ban = @config['ban'] || 3
    @flood_time = @config['time'] || 5
    @flood_size = @config['size'] || 10
    @length = @config['length'] || 31536000000
    @reason = @config['reason'] || 'Misbehaving in chat'
    @message = @config['warning'] || '%s: Please behave in chat'
    @regex = (@config['regex'] || []).map {|r| Regexp.new(r, 'im') }
    @caps = @config['caps'] || 101
    @caps_length = @config['caps_length'] || 7
    @points = {
      'flood' => 1,
      'swear' => 1,
      'caps' => 1
    }.merge(@config['points'])
    if File.exists? 'antispam.yml'
      @data = YAML::load_file 'antispam.yml'
    else
      @data = {}
      record
    end
    @flood = {}
  end

  def record
    File.open('antispam.yml', 'w+') {|f| f.write(@data.to_yaml) }
  end

  # @param [User] user
  # @param [String] message
  def check(user, message)
    # Legit check
    return if user.is? :mod or user.name == @client.config['user']
    # Setting defaults
    @data[user.name] ||= 0
    @flood[user.name] ||= []
    # Spam check
    @words.each {|w| execute(user, 'swear') if message.include? w }
    @regex.each {|r| execute(user, 'swear') if r =~ message }
    # Caps check
    caps_count = 0
    for i in 0...message.length
      if message[i].downcase != message[i]
        caps_count += 1
      end
    end
    execute(user, 'caps') if caps_count.to_f / message.length * 100.0 >= @caps and message.length >= @caps_length
    # Flood check
    time = Time.now.to_i
    @flood[user.name] << time
    @flood[user.name].shift if @flood[user.name].length > @flood_size
    execute(user, 'flood') if @flood[user.name].length >= @flood_size and time - @flood[user.name][0] <= @flood_time
  end

  # @param [User] user
  def execute(user, type)
    @data[user.name] += @points[type]
    if @data[user.name] >= @ban
      @client.ban user.name, @length.to_s, @reason
      @data[user.name] = 0
    elsif @data[user.name] >= @kick
      @client.kick user.name
    elsif @data[user.name] >= @warn
      @client.send_msg @message % user.name
    end
    record
  end

end

