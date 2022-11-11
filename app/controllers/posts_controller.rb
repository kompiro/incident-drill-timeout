class PostsController < ApplicationController
  def index
    client = service_client
    resonse = client.get('/')
    # 便宜的に連携先サービスから取得してきたデータを表示する
    render plain: response.body
  rescue Faraday::TimeoutError => ex
    render file: Rails.root.join('public/408.html'), status: :request_timeout
  end

  private 

  def service_client
    if TIMEOUT.present?
      Rails.logger.info("timeout: #{TIMEOUT} sec")
      Faraday.new(
        'http://localhost:4567',
        request: { timeout: TIMEOUT}
      )
    else
      Rails.logger.info("timeout: 60 sec (default)")
      Faraday.new('http://localhost:4567')
    end
  end
end