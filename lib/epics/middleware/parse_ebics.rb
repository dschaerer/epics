# frozen_string_literal: true

class Epics::ParseEbics < Faraday::Middleware
  def initialize(app = nil, options = {})
    super(app)
    @client = options[:client]
  end

  def call(env)
    @app.call(env).on_complete do |response|
      raw_body = response[:body]
      response[:body] = ::Epics::Response.new(@client, response[:body])
      begin
        File.binwrite(Rails.root.join('transactions', "#{response[:body].transaction_id&.present? ? response[:body].transaction_id : DateTime.now.strftime('%Y%m%d%H%M%S')}.response.xml"), raw_body)
      rescue StandardError => e
        Rails.logger.error('Could not write response file', e)
      end
      raise Epics::Error::TechnicalError, response[:body].technical_code if response[:body].technical_error?
      raise Epics::Error::BusinessError, response[:body].business_code if response[:body].business_error?
    end
  rescue Epics::Error::TechnicalError => e
    Rails.logger.error('Could not parse response due to technical error', e)
    raise # re-raise as otherwise they would be swallowed by the following rescue
  rescue Epics::Error::BusinessError => e
    Rails.logger.error('Could not parse response due to business error', e)
    raise # re-raise as otherwise they would be swallowed by the following rescue
  rescue StandardError => e
    Rails.logger.error('Could not parse response', e)
    raise Epics::Error::UnknownError, e
  end
end
