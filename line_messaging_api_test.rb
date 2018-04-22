require 'sinatra'
require 'line/bot'
require 'dotenv/load'
require 'aws-sdk'

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

get '/' do
  "Hello world"
end

post '/callback' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)
  events.each { |event|
    case event
      when Line::Bot::Event::Message
        case event.type
          when Line::Bot::Event::MessageType::Text
            message = {
                type: 'text',
                text: event.message['text']
            }
            client.reply_message(event['replyToken'], message)
          when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
            response = client.get_message_content(event.message['id'])
            tf = Tempfile.open("content")
            tf.write(response.body)
        end
    end
  }

  "OK"
end

post '/okay' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  place = '目黒'
  meal = ''
  events = client.parse_events_from(body)
  events.each { |event|
    case event
      when Line::Bot::Event::Message
        case event.type
          when Line::Bot::Event::MessageType::Text
            meal = event.message['text']
            message = {
                type: 'text',
                text: "#{place}で#{meal}、一緒に行こうね♡"
            }
            client.reply_message(event['replyToken'], message)
          when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
            response = client.get_message_content(event.message['id'])
            tf = Tempfile.open("content")
            tf.write(response.body)
        end
    end
  }

  put_s3(place, meal)
  "OK"
end

private

def put_s3(place, meal)
  now = Time.now
  time_format = now.strftime("%Y/%m/%d-%H:%M:%S.#{now.usec}")

  parameter = {
      bucket: 'spajamdojyo',
      key: "#{time_format}-message",
      body: { "place": "#{place}", "meal": "#{meal}" }.to_json,
  }
  s3.put_object(parameter)
end

def s3
  @s3 ||= Aws::S3::Client.new(
      :region => 'ap-northeast-1',
      access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
  )
end
