require 'time'

task :test, 'test'
task :test do |task, args|
  puts args.test
end

task :record, 'date'
task :record do |task, args|
  require './lib/chunithm_recoder.rb'
  cr = ChunithmRecorder.new
  cr.load(args.date ? Time.parse(args.date) : Time.now-60*60*24)
end

task :master
task :master do |task, args|
  require './lib/chunithm_recoder.rb'
  cr = ChunithmRecorder.new
  cr.get_master_data
end
