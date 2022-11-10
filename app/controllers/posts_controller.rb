class PostsController < ApplicationController
  def index
    client = default_client
    # client = set_timeout_client
    resonse = client.get('/')
    render plain: response.body
  end

  private 

  def default_client
    Faraday.new('http://localhost:4567')
  end

  def set_timeout_client
    Faraday.new(
      'http://localhost:4567',
      request: { timeout: 10 }
    )
end