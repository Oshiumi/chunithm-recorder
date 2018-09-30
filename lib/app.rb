require 'sinatra/base'
require 'json'
require 'time'
require './lib/chunithm_recoder.rb'

class ChunithmRecorderApi < Sinatra::Base
  configure do
    set :environment, :production
  end

  get '/test' do
    'test'
  end

  get '/chunithm-record' do
    cr = ChunithmRecorder.new
    begin
      cr.load
      status 200
    rescue => e
      puts e.backtrace.join("\n")
      status 500
    end
  end

  post '/chunithm-record' do
    cr = ChunithmRecorder.new
    cr.load(Time.parse(params[:date]))
  end

  get '/master' do
    cr = ChunithmRecorder.new
    cr.get_master_data
  end
end
