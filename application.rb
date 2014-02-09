require 'sinatra'
require 'sinatra/json'
require 'sinatra/cross_origin'
require 'public_suffix'
require 'rss'

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
        halt 404 if not PublicSuffix.valid?(params[:domain])
        conn = PG.connect :hostaddr => '172.17.42.1', :user => 'docker', :password => 'docker', :dbname => 'ct-watch'
        results = conn.exec_params("SELECT log_server.prefix AS logServerPrefix, idx, domain, encode(certificate, 'base64') as certificate FROM log_entry JOIN log_server ON log_server.id = log_server_id JOIN cert ON log_entry.cert_md5 = cert.md5 WHERE reverse(domain) = $1 OR reverse(domain) like ($1 || '.%')", [params[:domain].reverse])

        search = params[:domain]

        rss = RSS::Maker.make("atom") do |maker|
            maker.channel.author = "Certificate Transparency Watch"
            maker.channel.updated = Time.now.to_s
            maker.channel.about = "http://ct-watch.tom-fitzhenry.me.uk/domain/#{search}"
            maker.channel.title = "Certificates for #{search}"

            results.each do |cert|
                maker.items.new_item do |item|
                    item.title = cert['domain']
                    item.link = "https://#{cert['logServerPrefix']}/ct/v1/get-entries?start=#{cert['idx']}&end=#{cert['idx']}"
                    item.content.content = "-----BEGIN CERTIFICATE-----\n" + cert['certificate'] + "\n-----END CERTIFICATE-----"
                    item.updated = Time.now.to_s
                end
            end
        end

        rss.to_s
    end
end
