require 'sinatra'
require 'sinatra/json'
require 'sinatra/cross_origin'

class CtWatch < Sinatra::Base
    helpers Sinatra::JSON
    register Sinatra::CrossOrigin

    get '/logserver/:id' do
        cross_origin :allow_origin => 'http://ct-watch.tom-fitzhenry.me.uk'

        conn = PG.connect :hostaddr => '172.17.42.1', :user => 'docker', :password => 'docker', :dbname => 'ct-watch'
        results = conn.exec_params("SELECT sth.* FROM sth JOIN log_server ON sth.log_server_id = log_server.id WHERE log_server.name = $1", [params[:id]])
        good, bad = results.partition { |row| row.values_at('verified')[0] == 't' }
        json :good => good, :bad => bad
    end

    get '/domain/:domain' do
        conn = PG.connect :hostaddr => '172.17.42.1', :user => 'docker', :password => 'docker', :dbname => 'ct-watch'
        results = conn.exec_params("SELECT log_server_id, domain, encode(leaf_input, 'base64'), encode(extra_data, 'base64') FROM log_entry WHERE reverse(domain) like ($1 || '%')", [params[:domain].reverse])
        json :results => results.values
    end
end
