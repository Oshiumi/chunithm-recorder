require 'thor'
require 'time'
require './lib/chunithm_recorder.rb'

class ThorTasks < Thor
  package_name 'chunithm'

  desc 'record', 'Load to chunithm record'
  option :dry_run,
         type: :boolean,
         desc: 'Print records'
  option :date,
         type: :string,
         aliases: 'd',
         default: (Time.now-60*60*24).to_s,
         desc: 'Date load ex. YYYY/MM/DD'
  option :remote,
         type: :boolean,
         default: false,
         desc: 'Use Remote Driver'
  def record
    date = Time.parse(options[:date])
    puts "Record started #{date.strftime("%Y/%m/%d")}"
    ChunithmRecorder.new(dryrun: options[:dry_run], remote: options[:remote]).load(date)
    puts "Record finished"
  end

  desc 'test', 'test'
  option :foo,
         type: :boolean,
         default: false
  def test
    puts options[:foo]
  end

  desc 'notes', 'fetch notes data'
  option :dry_run,
         type: :boolean,
         desc: 'Print records'
  option :remote,
         type: :boolean,
         default: false,
         desc: 'Use Remote Driver'
  def notes
    ChunithmRecorder.new(dryrun: options[:dry_run], remote: options[:remote]).fetch_notes
  end

  desc 'rate_value', 'fetch rate value'
  option :dry_run,
         type: :boolean,
         desc: 'Print records'
  option :remote,
         type: :boolean,
         default: false,
         desc: 'Use Remote Driver'
  def rate_value
    ChunithmRecorder.new(dryrun: options[:dry_run], remote: options[:remote]).fetch_rate_values
  end

  desc 'record_history', 'fetch record history'
  option :dry_run,
         type: :boolean,
         desc: 'Print records'
  option :remote,
         type: :boolean,
         default: false,
         desc: 'Use Remote Driver'
  def record_history
    ChunithmRecorder.new(dryrun: options[:dry_run], remote: options[:remote]).fetch_record_history
  end
end
