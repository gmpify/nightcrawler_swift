module NightcrawlerSwift
  class Gateway

    attr_reader :resource, :attempts, :current_retry_time

    RETRY_BLACKLIST = [
      RestClient::Unauthorized,
      RestClient::ResourceNotFound,
      RestClient::UnprocessableEntity
    ]

    def initialize url
      @url = url
      @attempts = 0
      @current_retry_time = 1
      @retries = NightcrawlerSwift.options.retries
      @max_retry_time = NightcrawlerSwift.options.max_retry_time

      @resource = RestClient::Resource.new(
        @url,
        verify_ssl: NightcrawlerSwift.options.verify_ssl,
        timeout: NightcrawlerSwift.options.timeout
      )
    end

    def request &block
      begin
        @attempts += 1
        block.call(resource)

      rescue => e
        raise e unless recoverable?(e)
        wait(e) and retry
      end

    rescue RestClient::Unauthorized => e
      raise Exceptions::UnauthorizedError.new(e)

    rescue RestClient::ResourceNotFound => e
      raise Exceptions::NotFoundError.new(e)

    rescue RestClient::UnprocessableEntity => e
      raise Exceptions::ValidationError.new(e)

    rescue => e
      raise Exceptions::ConnectionError.new(e)
    end

    private
    def log message
      NightcrawlerSwift.logger.debug message
    end

    def recoverable? e
      @retries and
      !RETRY_BLACKLIST.include?(e.class) and
      @attempts <= @retries
    end

    def wait e
      number = "#{@attempts}/#{@retries}"
      log "Attempt #{number} to call '#{@url}', waiting #{@current_retry_time}s and retrying. Error: #{e.message}"
      sleep @current_retry_time
      @current_retry_time = [@current_retry_time * 2, @max_retry_time].min
    end

  end
end