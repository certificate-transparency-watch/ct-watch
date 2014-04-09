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
        results = conn.exec_params("SELECT log_server.prefix, idx, domain, encode(certificate, 'base64') as certificate FROM log_entry JOIN log_server ON log_server.id = log_server_id JOIN cert ON log_entry.cert_md5 = cert.md5 WHERE reverse(domain) = $1 OR reverse(domain) like ($1 || '.%')", [params[:domain].reverse])

        search = params[:domain]

        rss = RSS::Maker.make("atom") do |maker|
            maker.channel.author = "Certificate Transparency Watch"
            maker.channel.updated = Time.now.to_s
            maker.channel.about = "http://ct-watch.tom-fitzhenry.me.uk/domain/#{search}"
            maker.channel.title = "Certificates for #{search}"

            results.each do |cert|
                maker.items.new_item do |item|
                    item.title = cert['domain']
                    item.link = "https://#{cert['prefix']}/ct/v1/get-entries?start=#{cert['idx']}&end=#{cert['idx']}"
                    item.content.content = "-----BEGIN CERTIFICATE-----\n" + cert['certificate'] + "\n-----END CERTIFICATE-----"
                    item.updated = Time.now.to_s
                end
            end
        end

        rss.to_s
    end

    get '/health' do
        conn = PG.connect :hostaddr => '172.17.42.1', :user => 'docker', :password => 'docker', :dbname => 'ct-watch'

        results = conn.exec("SELECT max(timestamp) FROM sth GROUP BY log_server_id").values
        recent_sth = results.size >= 2 && results.all? { |i| Time.at(i[0].to_i/1000) > Time.now - (3*60*60) }
        halt 500, 'A log server has no STH in the past 3 hours.' if not recent_sth

        unprocessed_entries = conn.exec("select count(*) from log_entry where domain is null").values[0][0].to_i
        halt 500, "There are #{unprocessed_entries} unprocessed log entries." if unprocessed_entries > 100000

        sth_treesizes = conn.exec("select log_server_id, max(treesize) from sth group by log_server_id order by log_server_id").values
        log_entries_indexes = conn.exec("select log_server_id, max(idx) from log_entry group by log_server_id order by log_server_id").values
        halt 500, 'Some log servers have no log entries' if not sth_treesizes.size == log_entries_indexes.size
        halt 500, 'Log entries indexes and STH tree size have drifted, for at least one log server.' if sth_treesizes.zip(log_entries_indexes).all? { |a| (a[0][1].to_i - a[1][1].to_i).abs < 35000 }

        unverified_sths = conn.exec("select count(*) from sth where verified = false group by log_server_id").values
        halt 500, 'A log server has more than one unverified STH' if unverified_sths.any? { |i| i[0].to_i > 1 }

    end
end
