require 'sinatra'
require 'sinatra/reloader'

set :bind, '0.0.0.0'

get '/' do
  sleep 100
  'Hello world!'
end
