require_relative '../plugin'

class Chatbot::Admin
  include Chatbot::Plugin

  match /^quit/, :method => :quit
  match /^plugins/, :method => :list_plugins
  match /^ignore (.*)/, :method => :ignore
  match /^unignore (.*)/, :method => :unignore
  match /^commands|^help/, :method => :get_commands
  match /^source|^src|^git(?:hub)?/, :method => :source
  match /^kick (.*)/, :method => :kick
  match /^ban ([^\s]+) (\d+)\s?(.*)/, :method => :ban

  # @param [User] user
  def quit(user)
    if user.is? :admin
      @client.send_msg "#{user.name}: Now exiting chat..."
      sleep 0.5
      @client.quit
    end
  end

  # @param [User] user
  def get_commands(user)
    return if @client.config['wiki'].eql? 'central'
    commands = @client.plugins.collect {|plugin| plugin.class.matchers}.collect {|matchers| matchers.select {|matcher| matcher.use_prefix}}.flatten
    @client.send_msg(user.name + ', all defined commands are: ' + commands.collect{|m|m.pattern.to_s.gsub('(?-mix:^', m.prefix).gsub(/\$?\)$/, '')}.join(', ') + '. (Confused? Learn regex!)')
  end

  # @param [User] user
  def list_plugins(user)
    if user.is? :mod
      @client.send_msg "#{user.name}, Currently loaded plugins are: " + @client.plugins.collect{|p| p.class.to_s}.join(', ')
    end
  end

  # @param [User] user
  def ignore(user, target)
    if user.is? :mod
      if @client.userlist.key? target
        @client.userlist[target].ignore
      else
        User.new(target).ignore
      end
      @client.send_msg "#{user.name}: I'll now ignore all messages from #{target}."
    end
  end

  # @param [User] user
  # @param [String] target
  def unignore(user, target)
    if user.is? :mod
      if @client.userlist.key? target
        @client.userlist[target].unignore
      else
        User.new(target).unignore
      end
      @client.send_msg "#{user.name}: I'll now listen to all messages from #{target}."
    end
  end

  # @param [User] user
  # @param [String] target
  def kick(user, target)
    if user.is? :mod
      @client.kick target
    end
  end

  # @param [User] user
  # @param [String] target
  # @param [String] length
  # @param [String] reason
  def ban(user, target, length, reason)
    if user.is? :mod
      puts target, length.to_i, reason
      @client.ban target, length.to_i, reason
    end
  end

  # @param [User] user
  def source(user)
    @client.send_msg "#{user.name}: My source code can be seen at https://github.com/KockaAdmiralac/chatbot-rb - feel free to contribute!"
  end

end
