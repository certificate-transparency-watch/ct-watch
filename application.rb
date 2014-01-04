require 'sinatra'

class CtWatch < Sinatra::Base
    get '/' do
        conn = PG.connect :hostaddr => '172.17.42.1', :user => 'docker', :password => 'docker', :dbname => 'ct-watch'
        results = conn.exec("SELECT * FROM sth")
        good, bad = results.partition { |row| row.values_at('verified') }
        haml :index, :locals => { :good => good, :bad => bad }
    end
end
