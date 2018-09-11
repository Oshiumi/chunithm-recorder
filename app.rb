require 'selenium-webdriver'
require 'dotenv'
require 'json'
require 'google/cloud/bigquery'

Dotenv.load

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless')
driver = Selenium::WebDriver.for :chrome, options: options

driver.navigate.to 'https://chunithm-net.com/mobile/Index.html'

driver.find_element(:name, 'segaId').send_keys(ENV['CHUNITHM_SEGA_ID'])
driver.find_element(:name, 'password').send_keys(ENV['CHUNITHM_PASSWORD'])
driver.find_element(:xpath, '//div[contains(@class, "btn_login")]').click
driver.find_element(:xpath, '//div[contains(@class, "btn_select_aime")]').click
driver.find_element(:link_text, 'プレイ履歴').click

wait = Selenium::WebDriver::Wait.new(:timeout => 100)
record = []
50.times do |i|
  puts i
  wait.until { driver.find_element(:xpath, %Q|//a[contains(@onclick, "JavaScript:pageMove('PlaylogDetail',#{i});")]|).enabled? }
  driver.find_element(:xpath, %Q|//a[contains(@onclick, "JavaScript:pageMove('PlaylogDetail',#{i});")]|).click
  date = driver.find_element(:xpath, '//div[contains(@class, "box_inner01")]').text
  break unless date.match?(/^#{(Time.now-60*60*24).strftime("%Y-%m-%d")}/)
  title = driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_title")]').text
  score = driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_score_text")]').text[/([0-9,]+)/, 1].gsub(/,/, '_').to_i
  difficulty = driver
                 .find_element(:xpath, '//div[contains(@class, "play_track_result")]')
                 .find_element(:tag_name, 'img')
                 .property('src')[/common\/images\/icon_text_([a-z]+)\.png$/, 1]
  max_combo = driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_max_number")]').text
  justice_critical = driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_judgenumber text_critical")]').text
  justice = driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_judgenumber text_justice")]').text
  attack = driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_judgenumber text_attack")]').text
  miss = driver.find_element(:xpath, '//div[contains(@class, "play_musicdata_judgenumber text_miss")]').text
  tap, hold, slide, air, flick = driver.find_elements(:xpath, '//div[contains(@class, "play_musicdata_notesnumber")]').map(&:text).map(&:chop).map(&:to_f)
  driver.navigate.back
  record << {
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
end

File.open('tmp.json', 'w') do |f|
  record.each do |r|
    f.puts r.to_json
  end
end

bq = Google::Cloud::Bigquery.new(project: ENV['CHUNITHM_GCP_PROJECT'])
dataset = bq.dataset('chunithm') || bq.create_dataset('chunithm')
table = dataset.table('score') || dataset.create_table('score') do |t|
  t.schema do |s|
    s.load File.open('schema.json')
  end
end

table.load_job 'tmp.json', format: 'json'

File.delete('tmp.json')

