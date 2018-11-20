require 'selenium-webdriver'
require 'dotenv'
require 'json'
require 'google/cloud/bigquery'
require 'time'

class ChunithmRecorder
  def initialize(dryrun: false, remote: false)
    ENV['TZ'] = 'Asia/Tokyo'
    Dotenv.load
    @dryrun = dryrun
    @remote = remote
  end

  def load(day = Time.now-60*60*24)
    initialize_webdriver
    records = fetch_chunithm_record(day)
    if @dryrun
      p records
      return
    end
    load_to_bq(records, 'score')
  end

  def initialize_webdriver
    if @remote
      chrome_capabilities = Selenium::WebDriver::Remote::Capabilities.chrome('chromeOptions' => {args: ['--headless', '--no-sandbox']})
      @driver = Selenium::WebDriver.for :remote, url: ENV['SELENIUM_URL'], desired_capabilities: chrome_capabilities
    else
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless')
      options.add_argument('--no-sandbox')
      @driver = Selenium::WebDriver.for :chrome, options: options
    end
  end

  def login_chunithm
    wait = Selenium::WebDriver::Wait.new(:timeout => 5)
    @driver.navigate.to 'https://chunithm-net.com/mobile/'
    @driver.save_screenshot 'tmp.png'
    @driver.find_element(:name, 'segaId').send_keys(ENV['CHUNITHM_SEGA_ID'])
    @driver.find_element(:name, 'password').send_keys(ENV['CHUNITHM_PASSWORD'])
    @driver.find_element(:class_name, 'btn_login').click

    wait.until {@driver.find_element(:class_name, 'btn_select_aime').enabled? }
    @driver.find_element(:class_name, 'btn_select_aime').click
  end

  def fetch_chunithm_record(day)
    login_chunithm
    @driver.navigate.to 'https://chunithm-net.com/mobile/record/playlog'
    records = []
    wait = Selenium::WebDriver::Wait.new(timeout: 20)
    50.times do |i|
      retry_count = 0
      begin
        wait.until { @driver.find_element(:class_name, 'btn_see_detail').displayed? }
        @driver.find_elements(:class_name, 'btn_see_detail')[i].click
        puts @driver.current_url
        wait.until { @driver.find_element(:class_name, 'box_inner01').displayed? }
        puts date_text = @driver.find_element(:class_name, 'box_inner01').text
        return records if Time.parse(date_text) < day
        if day + 24 * 60 * 60 < Time.parse(date_text)
          @driver.navigate.to 'https://chunithm-net.com/mobile/record/playlog'
          next
        end
        date = Time.parse(date_text).to_i
        puts title = @driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_title")]').text
        score = @driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_score_text")]').text[/([0-9,]+)/, 1].gsub(/,/, '_').to_i
        difficulty = @driver
                       .find_element(:class_name, 'play_track_result')
                       .find_element(:tag_name, 'img')
                       .property('src')[/icon_text_([a-z]+)\.png$/, 1]
        max_combo = @driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_max_number")]').text.gsub(/,/, '_').to_i
        justice_critical = @driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_judgenumber text_critical")]').text.gsub(/,/, '_').to_i
        justice = @driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_judgenumber text_justice")]').text.gsub(/,/, '_').to_i
        attack = @driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_judgenumber text_attack")]').text.gsub(/,/, '_').to_i
        miss = @driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_judgenumber text_miss")]').text.gsub(/,/, '_').to_i
        tap, hold, slide, air, flick = @driver.find_elements(:xpath, '//div[contains(@class, "play_musicdata_notesnumber")]').map(&:text).map(&:chop).map(&:to_f)
        @driver.navigate.to 'https://chunithm-net.com/mobile/record/playlog'
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
        @driver.quit if @driver
        initialize_webdriver
        login_chunithm
        @driver.navigate.to 'https://chunithm-net.com/mobile/record/playlog'
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

  def fetch_rate_values
    difficulty = { 'MAS' => 'master', 'EXP' => 'expert'}

    initialize_webdriver
    @driver.navigate.to 'https://chuniviewer.net/ratevaluelist'
    table = @driver.find_element(:id, 'rate-list-table').find_element(:tag_name, 'tbody')
    records = table.find_elements(:tag_name, 'tr').map do |tr|
      e = tr.find_elements(:tag_name, 'td').map(&:text)
      e[2] = difficulty[e[2]]
      e.last ? ['level', 'title', 'difficulty', 'rate_value'].zip(e).to_h : nil
    end
    if @dryrun
      p records
    else
      load_to_bq(records.reject(&:nil?), 'rate_values')
    end
  end

  def fetch_notes
    initialize_webdriver
    wait = Selenium::WebDriver::Wait.new(:timeout => 5)

    @driver.navigate.to 'https://chunithm.gamerch.com/CHUNITHM%20STAR%20PLUS%20%E6%A5%BD%E6%9B%B2%E4%B8%80%E8%A6%A7'

    wait.until {@driver.find_element(:xpath, '//div[contains(@class, "star-midashi1")]').enabled?}
    p genres = @driver.find_elements(:xpath, '//div[contains(@class, "star-midashi1")]').map(&:text)[0..6]
    wait.until {@driver.find_element(:xpath, '//div[contains(@class, "t-line-img")]')}
    p tracks_url = @driver
               .find_element(:xpath, '//div[contains(@class, "t-line-img")]')
               .find_elements(:tag_name, 'tbody')[0..6]
               .map { |e| e.find_elements(:tag_name, 'tr')
                        .map { |e| e.find_element(:tag_name, 'th')
                                 .find_element(:tag_name, 'a').attribute('href')}
    }
    records = tracks_url.zip(genres).map { |urls,genre| urls.map { |url| fetch_track(url, genre)} }.flatten
    if @dryrun
      p records
    else
      load_to_bq(records, 'notes')
    end

  end

  def fetch_track(url,genre)
    wait = Selenium::WebDriver::Wait.new(:timeout => 5)
    @driver.navigate.to url
    wait.until {@driver.find_element(:xpath, '//span[contains(@id, "js_async_main_column_name")]').enabled?}
    p title = @driver.find_element(:xpath, '//span[contains(@id, "js_async_main_column_name")]').text
    wait.until {@driver.find_element(:tag_name, 'tbody').enabled?}
    exp, mas = @driver.find_elements(:tag_name, 'tbody')
                 .select { |e| e.find_element(:tag_name, 'tr').find_elements(:tag_name, 'th').map(&:text) == ['Lv', '総数', '内訳']}.first
                 .find_elements(:tag_name, 'tr')[4..5].map { |tr| tr.find_elements(:tag_name, 'td').map(&:text).map(&:to_i) }
    labels = ['all', 'tap', 'hold', 'slide', 'air', 'flick']
    [
      { 'title' => title, 'difficulty' => 'expert', 'genre' => genre}.merge(labels.zip(exp).to_h),
      { 'title' => title, 'difficulty' => 'master', 'genre' => genre}.merge(labels.zip(mas).to_h)
    ]
  end

  def fetch_record_history
    initialize_webdriver
    login_chunithm
    wait = Selenium::WebDriver::Wait.new(:timeout => 5)
    @driver.navigate.to 'https://chunithm-net.com/mobile/MusicGenre.html'
    wait.until { @driver.find_element(:class_name, 'btn_master').enabled? }
    @driver.find_element(:class_name, 'btn_master').click
    wait.until {@driver.find_element(:class_name, 'music_title').enabled?}
    onclick = @driver.find_elements(:class_name, 'musiclist_box')
                .select { |e| e.find_elements(:class_name, 'play_musicdata_highscore').size > 0 }
                .map { |e| e.find_element(:class_name, 'music_title').attribute('onclick')}
    records = onclick.map do |e|
      wait.until {@driver.find_element(:xpath, %Q|//div[contains(@onclick, "#{e}")]|).enabled?}
      @driver.find_element(:xpath, %Q|//div[contains(@onclick, "#{e}")]|).click
      wait.until { @driver.find_element(:class_name, 'play_musicdata_title') }
      puts title = @driver.find_element(:class_name, 'play_musicdata_title').text
      records = []
      if @driver.find_elements(:class_name, 'bg_master').size > 0
        master = @driver.find_element(:class_name, 'bg_master')
        records << {
          'title' => title,
          'difficulty' => 'master',
          'updated_at' => master.find_element(:class_name, 'musicdata_detail_date').text,
          'high_score' => master.find_element(:class_name, 'text_b').text.gsub(/,/, '_').to_i,
          'play_count' => master.find_element(:class_name, 'block_icon_text').find_elements(:tag_name, 'span').last.text
        }
      end

      if @driver.find_elements(:class_name, 'bg_expert').size > 0
        expert = @driver.find_element(:class_name, 'bg_expert')
        records << {
          'title' => title,
          'difficulty' => 'expert',
          'updated_at' => expert.find_element(:class_name, 'musicdata_detail_date').text,
          'high_score' => expert.find_element(:class_name, 'text_b').text.gsub(/,/, '_').to_i,
          'play_count' => expert.find_element(:class_name, 'block_icon_text').find_elements(:tag_name, 'span').last.text
        }
      end
      @driver.navigate.back
      records
    end

    if @dryrun
      p records
    else
      load_to_bq(records.flatten, 'record_history')
    end
  end
end

