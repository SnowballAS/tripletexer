# frozen_string_literal: true

require 'uri'
require 'json'
require 'faraday'
require 'faraday_middleware'


class Tripletexer::APIClient
  ENDPOINT = 'https://tripletex.no/'

  attr_reader :session_token, :debug

  def initialize(object_class: Hash, proxy: nil, debug: false)
    @object_class = object_class
    @proxy = proxy
    @debug = debug
  end

  def connection
    return @connection if session_token && @connection
    @connection = init_connection
  end

  def reset_connection
    @session_token = @connection = nil
  end

  def session_token=(new_session_token)
    reset_connection
    @session_token = new_session_token
  end

  def get(path, *args, &block)
    call(:get, path, *args, &block)
  end

  def post(path, *args, &block)
    call(:post, path, *args, &block)
  end

  def put(path, *args, &block)
    call(:put, path, *args, &block)
  end

  def delete(path, *args, &block)
    call(:delete, path, *args, &block)
  end

  private

  attr_reader :object_class, :proxy

  def init_connection
    Faraday.new(url: ENDPOINT) do |faraday|
      faraday.response :logger if debug
      faraday.response :json, parser_options: { object_class: object_class }, content_type: %r[/json$]
      faraday.headers = {
        'Content-Type' => 'application/json'
      }
      faraday.request :multipart
      faraday.request :url_encoded
      faraday.adapter :net_http
      faraday.basic_auth(0, session_token) if session_token
      faraday.proxy = proxy if proxy # https://github.com/lostisland/faraday/issues/733
    end
  end

  def call(method, path, *args, &block)
    normalized_path = URI.escape(path)
    response = connection.public_send(method, normalized_path, *args, &block)
    handle_response(response)
  end

  def handle_response(response)
    body = response.body
    case response.status
    when 200, 201, 204
      body
    when 400, 422
      raise ::Tripletexer::Errors::BadRequest, body
    when 401
      raise ::Tripletexer::Errors::Unauthorized, body
    when 403
      raise ::Tripletexer::Errors::Forbidden, body
    when 404
      raise ::Tripletexer::Errors::NotFound, body
    when 409
      raise ::Tripletexer::Errors::Conflict, body
    when 500
      raise ::Tripletexer::Errors::InternalError, body
    else
      raise NotImplementedError, "don't know how to handle #{response.status} http status code"
    end
  end

end
