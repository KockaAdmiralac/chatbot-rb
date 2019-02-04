require_relative '../plugin'

class WikiLog
  include Chatbot::Plugin

  match /^updatelogs$/, :method => :update_logs_command
  match /^logs$/, :method => :logs_command
  match /^updated$/, :method => :updated_command
  match /(.*)/, :method => :on_message, :use_prefix => false

  listen_to :join, :on_join
  listen_to :part, :on_part
  listen_to :kick, :on_kick
  listen_to :ban, :on_ban
  listen_to :quitting, :on_bot_quit

  CATEGORY_TS = '%Y %m %d'
  attr_accessor :log_thread, :buffer, :buffer_mutex

  # @param [Chatbot::Client] bot
  def initialize(bot)
    super(bot)
    @buffer = ''
    @buffer_mutex = Mutex.new
    @log_thread = make_thread
    @last_log = nil
    @options = {
      :log_interval => 3600,
      :title => 'Project:Chat/Logs/%d %B %Y',
      :type => :daily,
      :fifo_threshold => 5000,
      :category => 'Chat logs'
    }
    if bot.config.key? :wikilog
      @options = @options.merge(bot.config[:wikilog])
    end
    @headers = {
      'Cookie' => bot.access_header,
      'User-Agent' => bot.headers['User-Agent']
    }
  end

  # @return [Thread]
  def make_thread
    thr = Thread.new(@options) {
      sleep @options[:log_interval]
      update(true)
    }
    @client.threads << thr
    thr
  end


  def update(in_thr=false)
    @log_thread.kill unless in_thr
    update_logs
    @log_thread = make_thread
  end

  def update_logs
    @last_log = Time.now.utc
    title = Time.now.utc.strftime @options[:title]
    # Ideally, this is inside a buffer lock somewhere...
    text = @buffer.dup.gsub('<', '&lt;').gsub('>', '&gt;')
    @buffer = ''
    query = get_page_contents(title)
    id = query[:pageids][0]
    page = query[:pages][id.to_sym]
    page_content = ''
    if id != '-1'
      page_content = page[:revisions][0][:*]
    end
    token = page[:edittoken]
    if @options[:type].eql? :fifo
      if page_content.scan(/\n/).size >= @options[:fifo_threshold]
        text = "<pre class=\"ChatLog\">#{text}\n</pre>\n[[Category:#{@options[:category]}]]"
      else
        text = page_content.gsub('</pre>', text + '</pre>')
      end
    else # Daily or overwrite
      if page_content.empty? or @options[:type].eql? :overwrite
        text = "<pre class=\"ChatLog\">#{text}</pre>\n[[Category:#{@options[:category]}|#{Time.now.utc.strftime CATEGORY_TS}]]"
      else
        text = page_content.gsub('</pre>', '').gsub("\n[[Category:#{@options[:category]}|", "#{text}</pre>\n[[Category:#{@options[:category]}|")
      end
    end
    post = Net::HTTP::Post.new("#{@client.base_uri.path}/api.php", @headers)
    post.body = URI.encode_www_form({
      :action => 'edit',
      :bot => 1,
      :minor => 1,
      :title => title,
      :text => text,
      :format => 'json',
      :token => token,
      :summary => 'Updating chat logs'
    })
    @client.api.request(post)
  end

  # @param [User] user
  def update_logs_command(user)
    if user.is? :mod
      @buffer_mutex.synchronize do
        lines = @buffer.scan(/\n/).size
        update
        @client.send_msg "#{user.name}: [[Project:Chat/Logs|Logs]] updated (added ~#{lines} to log page)."
      end
    end
  end

  # @param [User] user
  def logs_command(user)
    @client.send_msg "#{user.name}: Logs can be seen [[Project:Chat/Logs|here]]."
  end

  # @param [User] user
  def updated_command(user)
    if @last_log.nil?
      @client.send_msg "#{user.name}: I haven't updated the logs since I joined here. There are currently ~#{@buffer.scan(/\n/).size} lines in the log buffer."
    else
      @client.send_msg "#{user.name}: I last updated the logs #{(Time.now.utc.to_i - @last_log.to_i) / 60} minutes ago. There are currently ~#{@buffer.scan(/\n/).size} lines in the log buffer."
    end
  end

  def on_bot_quit(*a)
    @log_thread.kill
    update_logs
  end

  # @param [Hash] data
  def on_ban(data)
    @buffer_mutex.synchronize do
      @buffer << "\n" + Util::ts + " -!- #{data['attrs']['kickedUserName']} was #{data['attrs']['time'] == 0 ? 'unbanned' : 'banned'} from Special:Chat by #{data['attrs']['moderatorName']}"
    end
  end

  # @param [Hash] data
  def on_kick(data)
    @buffer_mutex.synchronize do
      @buffer << "\n" + Util::ts + " -!- #{data['attrs']['kickedUserName']} was kicked from Special:Chat by #{data['attrs']['moderatorName']}"
    end
  end

  # @param [Hash] data
  def on_part(data)
    @buffer_mutex.synchronize do
      @buffer << "\n" + Util::ts + " -!- #{data['attrs']['name']} has left Special:Chat"
    end
  end

  # @param [Hash] data
  def on_join(data)
    @buffer_mutex.synchronize do
      @buffer << "\n" + Util::ts + " -!- #{data['attrs']['name']} has joined Special:Chat"
    end
  end

  # @param [User] user
  # @param [String] message
  def on_message(user, message)
    @buffer_mutex.synchronize do
      message.split(/\n/).each do |line|
        if /^\/me/.match(line) and message.start_with? '/me'
          @buffer << "\n" + Util::ts + " * #{user.log_name} #{line.gsub(/\/me /, '')}"
        elsif message.start_with? '/me'
          @buffer << "\n" + Util::ts + " * #{user.log_name} #{line.gsub(/\/me /, '')}"
        else
          @buffer << "\n" + Util::ts + " <#{user.log_name}> #{line}"
        end
      end
    end
  end

  # Gets the current text of a page
  # @param [String] title
  # @return [String]
  def get_page_contents(title)
    JSON.parse( 
      @client.api.get("#{@client.base_uri.path}/api.php?#{URI.encode_www_form({
        :action => 'query',
        :prop => 'info|revisions',
        :titles => title,
        :rvprop => 'content',
        :intoken => 'edit',
        :indexpageids => 1,
        :format => 'json',
        :cb => rand(1000000)
      })}", @headers).body,
      :symbolize_names => true
    )[:query]
  end

end
