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

  # @param [Hash] data
  def execute(data)
    seconds = data['attrs']['time'].to_i
    return if seconds == 0
    pagetext = get_page_contents
    page_text = ''
    if seconds == 31536000000
      text = '== Permabans ==' + pagetext.split('== Permabans ==')[1]
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
    @client.api.edit(BAN_PAGE, page_text, {
      :summary => "Adding ban for [[User:#{data['attrs']['kickedUserName']}|]]",
      :bot => 1
    })
  end

  # Gets the current text of a page - @client.api.get() will return nil and generally screw things up
  # @return [String]
  def get_page_contents()
    res = HTTParty.get(
      "https://#{@client.config['wiki']}.wikia.com/index.php",
      :query => {
        :title => BAN_PAGE,
        :action => 'raw',
        :cb => rand(1000000)
      }
    )
    res.body
  end
end
