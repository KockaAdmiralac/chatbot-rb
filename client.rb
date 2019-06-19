require 'erb'
require 'json'
require 'logger'
require 'net/http'
require 'uri'
require 'yaml'
require_relative './plugin'
require_relative './util'
require_relative './events'

$logger = Logger.new(STDERR)
$logger.level = Logger::WARN

module Chatbot
  # An HTTP client capable of connecting to Fandom's Special:Chat product.
  class Client
    include Events

    USER_AGENT = 'KockaAdmiralac/chatbot-rb v2.2.0 (fyi socket.io sucks) [https://github.com/KockaAdmiralac/chatbot-rb]'
    CONFIG_FILE = 'config.yml'

    attr_accessor :config, :handlers, :threads, :userlist
    attr_reader :access_header, :api, :base_uri, :headers, :plugins

    def initialize
      unless File.exists? CONFIG_FILE
        $logger.fatal "Config: #{CONFIG_FILE} not found!"
        exit
      end
      erb = ERB.new File.new(File.join(__dir__, CONFIG_FILE)).read
      @config = YAML.load erb.result(binding)
      if @config['domain'].nil? or @config['domain'].length == 0
        @config['domain'] = 'fandom.com'
      end
      if @config['wiki'].include? '.'
        @base_uri = URI.parse("http://#{@config['wiki']}.#{@config['domain']}")
      elsif @config['lang']
        @base_uri = URI.parse("https://#{@config['wiki']}.#{@config['domain']}/#{@config['lang']}")
      else
        @base_uri = URI.parse("https://#{@config['wiki']}.#{@config['domain']}")
      end
      @api = Net::HTTP.new(@base_uri.host, @base_uri.port)
      if @base_uri.port == 443
        @api.use_ssl = true
      end
      res = Net::HTTP.post_form(URI("https://services.#{@config['domain']}/auth/token"), {
        :username => @config['user'],
        :password => @config['password']
      })
      @access_header = res['Set-Cookie']
      @time_cachebuster = 0
      @headers = {
        'User-Agent' => USER_AGENT,
        'Cookie' => @access_header,
        'Content-Type' => 'text/plain;charset=UTF-8',
        'Accept' => '*/*',
        'Pragma' => 'no-cache',
        'Cache-Control' => 'no-cache',
        'Connection' => 'keep-alive'
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
      File.open(CONFIG_FILE, File::WRONLY) do |f|
        f.write(@config.to_yaml)
      end
    end

    # Fetch important data from chat
    def fetch_chat_info
      res = @api.get(
        "#{@base_uri.path}/wikia.php?#{URI.encode_www_form({
          :controller => 'Chat',
          :format => 'json'
        })}", @headers)
      # @type [Hash]
      data = JSON.parse(res.body, :symbolize_names => true)
      @key = data[:chatkey]
      @room = data[:roomId]
      @mod = data[:isChatMod]
      @initialized = false
      @server = JSON.parse(
        @api.get(
          "#{@base_uri.path}/api.php?#{URI.encode_www_form({
            :action => 'query',
            :meta => 'siteinfo',
            :siprop => 'wikidesc',
            :format => 'json'
          })}"
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
      @socket = Net::HTTP.new(data[:chatServerHost], 443)
      @socket.use_ssl = true
      @socket.keep_alive_timeout = 60
      @socket.ssl_timeout = 60
      Signal.trap('INT') do
        quit
      end
      Signal.trap('TERM') do
        quit
      end
      res = get
      spl = res.body.match(/\d+:0(.*)$/)
      if spl.nil?
        @running = false
        return
      end
      @request_options[:sid] = JSON.parse(spl.captures[0], :symbolize_names => true)[:sid]
      @headers['Cookie'] = res['Set-Cookie']
    end

    # Perform a GET request to the chat server
    def get
      opts = @request_options.merge({:time_cachebuster => Time.now.to_ms.to_s + '-' + @time_cachebuster.to_s})
      uri = URI("https://#{@socket.address}/socket.io/")
      uri.query = URI.encode_www_form(opts)
      @time_cachebuster += 1
      @socket.get(uri, @headers)
    end

    # Perform a POST request to the chat server with the specified body
    # @param [Hash] body
    def post(body)
      poster = Net::HTTP.new(@socket.address, @socket.port)
      poster.use_ssl = true
      poster.keep_alive_timeout = 60
      poster.ssl_timeout = 60
      body = Util::format_message(body == :ping ? '2' : "42#{[
        'message',
        {
          :id => nil,
          :attrs => body
        }.to_json
      ].to_json}")
      opts = @request_options.merge({
        :time_cachebuster => Time.now.to_ms.to_s + '-' + @time_cachebuster.to_s
      })
      uri = URI("https://#{@socket.address}/socket.io/")
      uri.query = URI.encode_www_form(opts)
      request = Net::HTTP::Post.new(uri.request_uri, @headers)
      request.body = body
      @time_cachebuster += 1
      poster.request(request)
    end

    # Run the bot
    def run!
      while @running
        begin
          res = get
          body = res.body.force_encoding('utf-8')
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
      @handlers[:quitting].each do |handler|
        handler.call(nil)
      end
      @threads.each do |thr|
        thr.join
      end
      @ping_thread.kill unless @ping_thread.nil?
    end

    # Make a ping thread
    def ping_thr
      @ping_thread = Thread.new do
        sleep 15
        post(:ping)
        ping_thr
      end
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
      if @socket.started?
        @socket.finish
      end
      puts 'Exiting...'
      exit
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
