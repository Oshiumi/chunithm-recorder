require 'time'

task :record, 'date'
task :record do |task, args|
  require './lib/chunithm_recoder.rb'
  cr = ChunithmRecorder.new
  puts args.date
  cr.load(Time.parse(args.date))
end

task :master
task :master do |task, args|
  require './lib/chunithm_recoder.rb'
  cr = ChunithmRecorder.new
  cr.get_master_data
end
