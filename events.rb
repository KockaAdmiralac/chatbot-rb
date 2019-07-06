module Chatbot
  module Events
    # @param [String] msg
    def on_socket_message(msg)
      begin
        # @type [Hash]
        json = JSON.parse(msg)[1]
        if json['event'] == 'disableReconnect' or json['event'] == 'forceReconnect' or !json.key? 'data'
          quit
          return
        end
        if json['data'].is_a? String
          json['data'] = JSON.parse(json['data'])
        end
        if json['event'] == 'chat:add' and not json['data']['id'].nil?
          json['event'] = 'message'
        elsif json['event'] == 'updateUser'
          json['event'] = 'update_user'
        end
        begin
          self.method("on_chat_#{json['event']}".to_sym).call(json['data'])
        rescue NameError
          # rip
        end
        @handlers[json['event'].to_sym].each { |handler| handler.call(json['data']) } if json['event'] != 'message' and @handlers.key? json['event'].to_sym
      rescue => e
        $logger.fatal e
      end
    end

    # @param [Hash] data
    def on_chat_message(data)
      begin
        message = data['attrs']['text']
        user = @userlist[data['attrs']['name']]
        @handlers[:message].each { |handler| handler.call(message, user) }
      rescue => e
        $logger.fatal e
      end
    end

    # @param [Hash] data
    def on_chat_initial(data)
      ping_thr
      data['collections']['users']['models'].each do |user|
        attrs = user['attrs']
        @userlist[attrs['name']] = User.new(self, attrs['name'], attrs['isModerator'], attrs['canPromoteModerator'], attrs['isStaff'])
      end
      @initialized = true
    end

    # @param [Hash] data
    def on_chat_join(data)
      if data['attrs']['name'] == @config['user'] and !@initialized
        post(:msgType => :command, :command => :initquery)
      end
      @userlist_mutex.synchronize do
        @userlist[data['attrs']['name']] = User.new(self, data['attrs']['name'], data['attrs']['isModerator'], data['attrs']['canPromoteModerator'], data['attrs']['isStaff'])
      end
    end

    # @param [Hash] data
    def on_chat_part(data)
      @userlist_mutex.synchronize do
        @userlist.delete(data['attrs']['name'])
      end
    end

    # @param [Hash] data
    def on_chat_logout(data)
      @userlist_mutex.synchronize do
        @userlist.delete(data['attrs']['name'])
      end
    end
  end
end
