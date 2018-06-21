require 'httparty'
require_relative '../plugin'

class Chatbot::Discord
  include Chatbot::Plugin

  match /(.*)/, :method => :on_message, :use_prefix => false

  listen_to :join, :on_join
  listen_to :part, :on_part
  listen_to :logout, :on_logout
  listen_to :kick, :on_kick
  listen_to :ban, :on_ban
  listen_to :quitting, :on_bot_quit

  def initialize(bot)
    super(bot)
    config = bot.config['discord']
    @url = "https://discordapp.com/api/webhooks/#{config['id']}/#{config['token']}"
  end

  def on_bot_quit(*a)
    send('The bot has left the chat')
  end

  def on_ban(data)
    p data
    a = data['attrs']
    send("#{a['kickedUserName']} was #{a['time'] == 0 ? 'unbanned' : 'banned'} from chat by #{a['moderatorName']} (\"#{a['reason']}\")")
  end

  def on_kick(data)
    a = data['attrs']
    send("#{a['kickedUserName']} was kicked from chat by #{a['moderatorName']}")
  end

  def on_part(data)
    send("#{data['attrs']['name']} has left the chat")
  end

  def on_logout(data)
    send("#{data['attrs']['name']} logged out")
  end

  def on_join(data)
    send("#{data['attrs']['name']} has joined the chat")
  end

  def on_message(user, message)
    send(message, user.name)
  end

  def send(message, user = "")
    HTTParty.post(@url, :body => {
      :content => message.gsub('@', '@​').gsub('discord.gg', 'discord.​gg'),
      :username => user
    })
  end

end
