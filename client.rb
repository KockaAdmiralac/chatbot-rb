require 'httparty'
require 'media_wiki'
require 'logger'
require_relative './plugin'
require_relative './util'
require_relative './events'

$logger = Logger.new(STDERR)
$logger.level = Logger::WARN

module Chatbot
  # An HTTP client capable of connecting to Wikia's Special:Chat product.
  class Client
    include HTTParty
    include Events

    USER_AGENT = 'sactage/chatbot-rb v2.2.0 (fyi socket.io sucks) [http://github.com/sactage/chatbot-rb]'
    CONFIG_FILE = 'config.yml'

    attr_accessor :session, :clientid, :handlers, :config, :userlist, :api, :threads
    attr_reader :plugins

    def initialize
      unless File.exists? CONFIG_FILE
        $logger.fatal "Config: #{CONFIG_FILE} not found!"
        exit
      end
      @config = YAML.load_file(File.join(__dir__, CONFIG_FILE))
      @base_url = @config.key?('dev') ? 'http://localhost:8080' : "http://#{@config['wiki']}.wikia.com"
      @api = MediaWiki::Gateway.new @base_url + '/api.php'
      @api.login(@config['user'], @config['password'])
      @time_cachebuster = 0
      @headers = {
          'User-Agent' => USER_AGENT,
          'Cookie' => @api.cookies.map { |k, v| "#{k}=#{v};" }.join(' '),
          'Content-Type' => 'text/plain;charset=UTF-8',
          'Accept' => '*/*',
          'Pragma' => 'no-cache',
          'Cache-Control' => 'no-cache'
      }
      @userlist = {}
      @userlist_mutex = Mutex.new
      @running = true
      fetch_chat_info
      @threads = []
      @ping_thread = nil
      @plugins = []
      @handlers = {
          :message => [],
          :join => [],
          :part => [],
          :kick => [],
          :logout => [],
          :ban => [],
          :update_user => [],
          :quitting => []
      }
    end

    # Register plugins with the client
    # @param [Array<Plugin>] plugins The list of plugin classes to register
    def register_plugins(*plugins)
      plugins.each do |plugin|
        @plugins << plugin.new(self)
        @plugins.last.register
      end
    end

    # Save the current configuration to disk
    def save_config
      File.open(CONFIG_FILE, File::WRONLY) { |f| f.write(@config.to_yaml) }
    end

    # Fetch important data from chat
    def fetch_chat_info
      # @type [HTTParty::Response]
      res = HTTParty.get("#{@base_url}/wikia.php?controller=Chat&format=json", :headers => @headers)
      # @type [Hash]
      data = JSON.parse(res.body, :symbolize_names => true)
      @key = data[:chatkey]
      @room = data[:roomId]
      @mod = data[:isChatMod]
      @initialized = false
      @server = JSON.parse(
        HTTParty.get(
          @base_url +
          '/api.php?action=query&meta=siteinfo&siprop=wikidesc&format=json'
        ).body,
        :symbolize_names => true
      )[:query][:wikidesc][:id] # >.>
      @request_options = {
          :name => @config['user'],
          :EIO => 2,
          :transport => 'polling',
          :key => @key,
          :roomId => @room,
          :serverId => @server
      }
      if @config.key?('dev')
        self.class.base_uri "http://#{data[:chatServerHost]}:#{data[:chatServerPort]}/"
      else
        self.class.base_uri "http://#{data[:chatServerHost]}/"
      end
      res = get
      spl = res.match(/\d+:0(.*)$/)
      if spl.nil?
        @running = false
        return
      end
      @request_options[:sid] = JSON.parse(spl.captures[0], :symbolize_names => true)[:sid]
      @headers['Cookie'] = res.headers['set-cookie']
    end

    # Perform a GET request to the chat server
    # @return [HTTParty::Response]
    def get(path: '/socket.io/')
      opts = @request_options.merge({:time_cachebuster => Time.now.to_ms.to_s + '-' + @time_cachebuster.to_s})
      @time_cachebuster +=1
      self.class.get(path, :query => opts, :headers => @headers)
    end

    # Perform a POST request to the chat server with the specified body
    # @param [Hash] body
    def post(body)
      body = Util::format_message(body == :ping ? '2' : '42' + ["message", {:id => nil, :attrs => body}.to_json].to_json)
      opts = @request_options.merge({:time_cachebuster => Time.now.to_ms.to_s + '-' + @time_cachebuster.to_s})
      @time_cachebuster += 1
      self.class.post('/socket.io/', :query => opts, :body => body, :headers => @headers)
    end

    # Run the bot
    def run!
      while @running
        begin
          res = get
          body = res.body
          if body.include? 'Session ID unknown'
            @running = false
            break
          end
          while body.length > 0
            index = body.index(':')
            msgend = index + body[0..index].to_i
            msg = body[index + 1..msgend]
            body = body[msgend + 1..-1]
            spl = msg.match(/^42(.*)$/)
            if spl
              spl.captures.each do |message|
                @threads << Thread.new(message) do
                  on_socket_message(message)
                end
              end
            end
          end
        rescue => e
          $logger.fatal e
          @running = false
        end
      end
      @handlers[:quitting].each { |handler| handler.call(nil) }
      @threads.each { |thr| thr.join }
      @ping_thread.kill unless @ping_thread.nil?
    end

    # Make a ping thread
    def ping_thr
      @ping_thread = Thread.new {
        sleep 15
        post(:ping)
        ping_thr
      }
    end

    # Sends a message to chat
    # @param [String] text
    def send_msg(text)
      post(:msgType => :chat, :text => text, :name => @config['user'])
    end

    # Kicks a user from chat. Requires mod rights (or above)
    # @param [String] user
    def kick(user)
      post(:msgType => :command, :command => :kick, :userToKick => user)
    end

    # Quits chat
    def quit
      @running = false
      post(:msgType => :command, :command => :logout)
    end

    # Bans a user from chat. Requires mod rights (or above)
    # @param [String] user
    # @param [Fixnum] length
    # @param [String] reason
    def ban(user, length, reason)
      post(:msgType => :command, :command => :ban, :userToBan => user, :time => length, :reason => reason)
    end
  end
end
