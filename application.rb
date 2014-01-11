require 'sinatra'
require 'sinatra/json'

class CtWatch < Sinatra::Base
    helpers Sinatra::JSON

    get '/logserver/:id' do
        conn = PG.connect :hostaddr => '172.17.42.1', :user => 'docker', :password => 'docker', :dbname => 'ct-watch'
        results = conn.exec_params("SELECT sth.* FROM sth JOIN log_server ON sth.log_server_id = log_server.id WHERE log_server.name = $1", [params[:id]])
        good, bad = results.partition { |row| row.values_at('verified') }
        json :good => good, :bad => bad
    end
end
