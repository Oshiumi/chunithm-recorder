require 'selenium-webdriver'
require 'dotenv'
require 'json'
require 'google/cloud/bigquery'
require 'time'

class ChunithmRecorder
  def initialize
    ENV['TZ'] = 'Asia/Tokyo'
    Dotenv.load
    @options = Selenium::WebDriver::Chrome::Options.new
    @options.add_argument('--headless')
    @options.add_argument('--no-sandbox')
  end

  def load(day = Time.now-60*60*24)
    go_to_history
    load_to_bq(fetch_chunithm_record(day), 'score')
  end

  def go_to_history
    puts "-" * 100
    @driver.quit if @driver
    @driver = Selenium::WebDriver.for :chrome, options: @options
    @driver.navigate.to 'https://chunithm-net.com/mobile/Index.html'
    @driver.find_element(:name, 'segaId').send_keys(ENV['CHUNITHM_SEGA_ID'])
    @driver.find_element(:name, 'password').send_keys(ENV['CHUNITHM_PASSWORD'])
    @driver.find_element(:xpath, '//div[contains(@class, "btn_login")]').click

    @driver.find_element(:xpath, '//div[contains(@class, "btn_select_aime")]').click

    @driver.find_element(:link_text, 'プレイ履歴').click
  end

  def fetch_chunithm_record(day)
    records = []
    50.times do |i|
      retry_count = 0
      begin
        wait = Selenium::WebDriver::Wait.new(:timeout => 20)
        wait.until { @driver.find_element(:xpath, %Q|//a[contains(@onclick, "JavaScript:pageMove('PlaylogDetail',#{i});")]|).enabled? }
        @driver.find_element(:xpath, %Q|//a[contains(@onclick, "JavaScript:pageMove('PlaylogDetail',#{i});")]|).click
        date_element = @driver.find_element(:xpath, '//div[contains(@class, "box_inner01")]')
        wait.until { date_element.enabled? }
        puts date = date_element.text
        return records if Time.parse(date) < day
        unless date.match?(/#{day.strftime("%Y-%m-%d")}/)
          @driver.navigate.back
          next
        end
        puts title = @driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_title")]').text
        score = @driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_score_text")]').text[/([0-9,]+)/, 1].gsub(/,/, '_').to_i
        difficulty = @driver
                       .find_element(:xpath, '//div[contains(@class, "play_track_result")]')
                       .find_element(:tag_name, 'img')
                       .property('src')[/common\/images\/icon_text_([a-z]+)\.png$/, 1]
        max_combo = @driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_max_number")]').text
        justice_critical = @driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_judgenumber text_critical")]').text
        justice = @driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_judgenumber text_justice")]').text
        attack = @driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_judgenumber text_attack")]').text
        miss = @driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_judgenumber text_miss")]').text
        tap, hold, slide, air, flick = @driver.find_elements(:xpath, '//div[contains(@class, "play_musicdata_notesnumber")]').map(&:text).map(&:chop).map(&:to_f)
        @driver.navigate.back
        records << {
          'title' => title,
          'score' => score,
          'date' => date,
          'difficulty' => difficulty,
          'max_combo' => max_combo,
          'justice_critical' => justice_critical,
          'justice' => justice,
          'attack' => attack,
          'miss' => miss,
          'tap' => tap,
          'hold' => hold,
          'slide' => slide,
          'air' => air,
          'flick' => flick
        }
      rescue => e
        puts "#{e.message} #{e.backtrace.join("\n")}"
        retry_count += 1
        puts "retry #{retry_count} times"
        raise 'Failed to fetch data' if retry_count > 3
        go_to_history
        retry
      end
    end
    records
  end

  def load_to_bq(records, table_id)
    File.open('tmp.json', 'w') do |f|
      records.each do |r|
        f.puts r.to_json
      end
    end

    begin
      bq = Google::Cloud::Bigquery.new(project: ENV['CHUNITHM_GCP_PROJECT'])
      dataset = bq.dataset('chunithm') || bq.create_dataset('chunithm')
      table = dataset.table(table_id) || dataset.create_table(table_id) do |t|
        t.schema do |s|
          s.load File.open("config//#{table_id}.json")
        end
      end

      table.load_job 'tmp.json', format: 'json'
    rescue => e
      retry
    end
  end

  def get_master_data
    difficulty = { 'MAS' => 'master', 'EXP' => 'expert'}

    driver = Selenium::WebDriver.for :chrome, options: @options
    driver.navigate.to 'https://chuniviewer.net/ratevaluelist'
    table = driver.find_element(:id, 'rate-list-table').find_element(:tag_name, 'tbody')
    records = table.find_elements(:tag_name, 'tr').map do |tr|
      e = tr.find_elements(:tag_name, 'td').map(&:text)
      e[2] = difficulty[e[2]]
      e.last ? ['level', 'title', 'difficulty', 'rate_value'].zip(e).to_h : nil
    end
    p records
    load_to_bq(records.reject(&:nil?), 'master')
  end
end

