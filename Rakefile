require 'time'

task :record, 'date'
task :record do |task, args|
  require './lib/chunithm_recoder.rb'
  cr = ChunithmRecorder.new
  puts args.date
  cr.load(Time.parse(args.date))
end
