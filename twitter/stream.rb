require 'rubygems'
require 'twitter'
require 'iconv'

#Filters non-UTF8 octets
def UTF8Filter(string)
    ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
    #Attention please, don't remove + ' ')[0..-2] it is used for UTF8 validation
    ic.iconv(string + ' ')[0..-2]
end

def listen_twitter_stream(hub, author_id)
  connected = false
  while !connected
    begin
      client = Twitter::Streaming::Client.new do |config|
        config.consumer_key        = hub.twitter_consumer_key
        config.consumer_secret     = hub.twitter_consumer_secret
        config.access_token        = hub.twitter_access_token
        config.access_token_secret = hub.twitter_access_token_secret
      end
      connected = true
    rescue => e
      puts "Error connecting to twitter stream: #{e.inspect}"
      sleep 10
    end
  end
  while true
    begin
      client.filter(:track => hub.twitter_hashtags) do |object|
        if object.is_a?(Twitter::Tweet)
          puts '@' + object.user.screen_name	+ ' said: ' + object.text
#          puts object.user.profile_image_url 	
          comment = Comment.new
          comment.title = 'hub-message-twitter'
          comment.source = hub
          comment.body = UTF8Filter(object.text)
          comment.author_id = author_id
          comment.name = UTF8Filter(object.user.screen_name)
          comment.email = 'admin@localhost.local'
          begin
            comment.save!
          rescue => e
            puts "Erro gravando comentário twitter #{e.inspect}"
          end
        end
      end
    rescue => e
      puts "Erro lendo stream #{e.inspect}"
      sleep 10
      break
    end
  end
end