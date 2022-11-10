require 'sinatra'
require 'sinatra/reloader'

get '/' do
  sleep 100
  'Hello world!'
end
