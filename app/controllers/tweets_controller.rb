class TweetsController < ApplicationController
  require 'oauth'
  require "json"
  require "oauth2"
  
  def index 
    twitter_info = get_twitter_info 
    @name = twitter_info["name"]
    @number_of_tweets = twitter_info["number_of_tweets"]
    @error_code = twitter_info["error_code"]
    @data = compose_tweets
  end
  
  def buff_client
    client_id = "YOUR_CLIENT_ID_FROM_BUFFERAPP"
    client_secret = "YOUR_CLIENT_SECRET_FROM_BUFFERAPP"
    site = "https://bufferapp.com/1/"
    client = OAuth2::Client.new(client_id, client_secret, :site => site)
    client
  end

  def buff_token(client)
    token = OAuth2::AccessToken.new(client, "YOUR_TOKEN_FROM_BUFFERAPP")
  end
  
  def send_to_bufferapp
    client = buff_client
    token = buff_token(client)
    profile_id = "YOUR_PROFILE_ID_FROM_BUFFERAPP"   
    post_path = "https://api.bufferapp.com/1/updates/create.json"    
    
    tweets = compose_tweets
    
    tweets.each do |new_tweet|
        data = {body: {"text" => new_tweet, "profile_ids" =>[profile_id], "shorten" => false}}
        token.post(post_path, data)
        puts "Sent to buffer: #{new_tweet}"
    end
  end
  
   def tweet
      full_tweets = compose_tweets   
      consumer_key = tweet_consumer_key
      access_token = tweet_access_token
      
     full_tweets.each do |new_tweet|
      baseurl = "https://api.twitter.com"
      path    = "/1.1/statuses/update.json"
      address = URI("#{baseurl}#{path}")
      request = Net::HTTP::Post.new address.request_uri
      request.set_form_data(
        "status" => new_tweet,
      )

      http             = Net::HTTP.new address.host, address.port
      http.use_ssl     = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      request.oauth! http, consumer_key, access_token
      http.start
      response = http.request request

      tweet = nil
      if response.code == '200' then
        tweet = JSON.parse(response.body)
        puts "Successfully sent #{tweet["text"]}"
      else
        puts = "Could not send the Tweet! " +
        "Code:#{response.code} Body:#{response.body}"
      end
     end
    end
  
  def compose_tweets
    news = filter_data
    
    raw_tweets = []
      
    news.each do |key, value|
      short_url = shorten_url(value.strip)
      if key.length + " ".length + short_url.length <= 140
        raw_tweets << key + " " + short_url
      end
    end   
    
    full_tweets = []
    raw_tweets.each do |tweet|
      new_tweet = add_hashtag(tweet)
      full_tweets << new_tweet
    end
    
    full_tweets
   end
  
  def add_hashtag(raw_tweet)
    keywords = ["JavaScript", "HTML", "Ruby", "CSS"]
    new_tweet = raw_tweet
    
    keywords.each do |keyword|
      if raw_tweet.downcase.include? keyword.downcase 
        if new_tweet.length + " #".length + keyword.length <= 140
          new_tweet = raw_tweet + " #" + keyword
        end
      end
    end
    new_tweet  
  end
  
  def shorten_url(url)
    base_url ="https://api-ssl.bitly.com/v3/shorten?access_token="
    access_token = "YOUR_ACCESS_TOKEN_FROM_BITLY" 
    uri = URI.parse("#{base_url}#{access_token}&longUrl=#{url}")
    
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    bitly_response = JSON.parse(response.body)
    short_url = bitly_response["data"]["url"]
    
    short_url
  end
  
  def get_news
    keywords = ["JavaScript", "HTML", "Ruby", "CSS"].shuffle
    news = []
    keywords.each do |keyword|

      keyword_srch = "%22#{keyword}%22"
      
      base_url ="https://hn.algolia.com/api/v1/search_by_date?restrictSearchableAttributes=title&query="
      uri = URI.parse("#{base_url}#{keyword_srch}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      hn_response_json = JSON.parse(response.body)
      news << hn_response_json
    end
    news
  end
  
  def get_data_from_news
    news = get_news
    data = {}
    dates = []
    news.each do |news|
      news["hits"].each do |arr|
        data[arr["title"]]=arr["url"]
        dates <<  Time.parse(arr["created_at"]).to_formatted_s(:day_and_month)
      end
    end
    return data, dates
  end
  
  def filter_data
    data = get_data_from_news
    news_and_url = data[0]
    dates = data[1]
    
    yesterdays_news = filter_for_date(news_and_url, dates)
    
    has_url_news = has_url(yesterdays_news)
    clean_news = trim_for_show(has_url_news)
    clean_news
  end
  
  def trim_for_show(has_url)
    clean_news = {}
    has_url.each_with_index do |(key, value), index|
      if key.include? "Show HN:"
        where_strip = key.index(':')+2
        no_show = key[where_strip..key.length]
        clean_news[no_show] = value
      else
        clean_news[key] = value
      end
    end
    clean_news
  end
  
  def has_url(yesterdays_news)
    has_url_news = {}
    yesterdays_news.each do |key, value|
      if not value.blank?
        has_url_news[key] = value
      end
    end
    has_url_news
  end
  
  
  def filter_for_date(news_and_url, dates)
    #select news only from yesterday
    yesterday = (Time.now - 2.days)
    yesterday = yesterday.to_formatted_s(:day_and_month)
    
    yesterdays_news = {}
    
    news_and_url.each_with_index do |(key, value),index|
      if dates[index] == yesterday
        yesterdays_news[key] = value
      end
    end
    yesterdays_news
  end
  
  def get_twitter_info
    consumer_key = tweet_consumer_key
      access_token = tweet_access_token
    
      baseurl = "https://api.twitter.com"
      address = URI("#{baseurl}/1.1/account/verify_credentials.json")

      http = Net::HTTP.new address.host, address.port
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      request = Net::HTTP::Get.new address.request_uri
      request.oauth! http, consumer_key, access_token

      http.start
      response = http.request request      
    twitter_info = {"name" =>"","number_of_tweets"=>"","error_code"=>"" }
      if response.code == '200'
        parsed_response = JSON.parse(response.body)
        twitter_info["name"] = parsed_response["name"]
        twitter_info["number_of_tweets"] = parsed_response["statuses_count"]
      else
        twitter_info["error_code"] = response.code
      end
    twitter_info
  end
  
  def tweet_consumer_key
    consumer_key = OAuth::Consumer.new(
        "YOUR_CONSUMER_KEY_FROM_TWITTER",
        "YOUR_CONSUMER_SECRET_FROM_TWITTER")
  end
  
  def tweet_access_token
    access_token = OAuth::Token.new(
        "YOUR_ACCESS_TOKEN_FROM_TWITTER",
        "YOUR_ACCESS_SECRET_FROM_TWITTER")
  end
end
