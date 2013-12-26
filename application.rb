require 'sinatra'

class CtWatch < Sinatra::Base
    get '/' do
        haml :index, :locals => { :greeting => 'hola' }
    end
end
