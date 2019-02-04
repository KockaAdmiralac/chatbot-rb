require 'uri'
require_relative '../plugin'

class Chatbot::BanNotify
  include Chatbot::Plugin

  listen_to :ban, :execute

  # BAN_TEMPLATE = 'User:SpongeBobiaChatBot/chatban'
  BAN_PAGE = 'Project:Chat/Bans'
  REPLACE_TEMP = <<-repl.gsub(/^\s+/, '')
  == Temporary bans ==
  {| class="wikitable sortable"
    ! Username
    ! Ban date
    ! Ban expires
    ! Reason
    ! Chatmod issuing ban
    ! Notes
    |-
  repl

  def initialize(bot)
    super(bot)
    @headers = {
      'Cookie' => bot.access_header,
      'User-Agent' => bot.headers['User-Agent']
    }
  end

  # @param [Hash] data
  def execute(data)
    seconds = data['attrs']['time'].to_i
    return if seconds == 0
    query = get_page_contents
    id = query[:pageids][0]
    page = query[:pages][id.to_sym]
    pagetext = ''
    if id != '-1'
      pagetext = page[:revisions][0][:*]
    end
    token = page[:edittoken]
    page_text = ''
    if seconds == 31536000000
      text = '== Permanent bans ==' + pagetext.split('== Permanent bans ==')[1]
      new_text = text.gsub /\|\}/, <<-repl.gsub(/^\s+/, '')
      |-
      | [[User:#{data['attrs']['kickedUserName']}|]]
      | #{Time.now.utc.strftime('%B %d, %Y')}
      | #{data['attrs']['reason']}
      | [[User:#{data['attrs']['moderatorName']}|]]
      |}
      repl
      page_text = pagetext.gsub(text, new_text)
    else
      expiry = Time.at(Time.now.to_i + seconds).utc.strftime '%B %d, %Y'
      replace = <<-repl.gsub(/^\s+/, '')
      == Temporary bans ==
      {| class="wikitable sortable"
      ! Username
      ! Ban date
      ! Ban expires
      ! Reason
      ! Chatmod issuing ban
      ! Notes
      |-
      | [[User:#{data['attrs']['kickedUserName']}|]]
      | #{Time.now.utc.strftime('%B %d, %Y')}
      | #{expiry}
      | #{data['attrs']['reason']}
      | [[User:#{data['attrs']['moderatorName']}|]]
      | Automatically added by [[User:#{@client.config['user']}|]]
      |-
      repl
      page_text = pagetext
      page_text.gsub!(REPLACE_TEMP, replace)
      # @client.api.edit('User_talk:' + data['attrs']['kickedUserName'], "{{subst:#{BAN_TEMPLATE}|#{data['attrs']['moderatorName']}|#{expiry}|#{Time.now.utc.strftime("%H:%M, %B %d, %Y (UTC)")}|#{data['attrs']['reason']}}}", {:section => 'new'})
    end
    post = Net::HTTP::Post.new("#{@client.base_uri.path}/api.php", @headers)
    post.body = URI.encode_www_form({
      :action => 'edit',
      :bot => 1,
      :minor => 1,
      :title => BAN_PAGE,
      :text => page_text,
      :format => 'json',
      :token => token,
      :summary => "Adding ban for [[User:#{data['attrs']['kickedUserName']}|]]"
    })
    @client.api.request(post)
  end

  # Gets the current text of a page
  # @return [String]
  def get_page_contents()
    JSON.parse( 
      @client.api.get("#{@client.base_uri.path}/api.php?#{URI.encode_www_form({
        :action => 'query',
        :prop => 'info|revisions',
        :titles => BAN_PAGE,
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
